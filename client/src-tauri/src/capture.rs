//! Native screen capture behind the in-app share picker.
//!
//! The WebView's own `getDisplayMedia()` picker can't be styled or driven: there
//! is no API to enumerate sources or preselect one (WebView2's
//! `ScreenCaptureStarting` event only allows or cancels the built-in UI). So the
//! app captures the chosen window or screen itself — frames are grabbed here,
//! JPEG-encoded, and streamed to the frontend, which paints them onto a canvas
//! and publishes that canvas as the screen-share track.

use std::{
    sync::{
        atomic::{AtomicBool, AtomicUsize, Ordering},
        mpsc::RecvTimeoutError,
        Arc, Mutex,
    },
    thread,
    time::{Duration, Instant},
};

use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use serde::Serialize;
use tauri::ipc::{Channel, InvokeResponseBody};
use xcap::{
    image::{codecs::jpeg::JpegEncoder, imageops::FilterType, RgbaImage},
    Monitor, Window,
};

/// Thumbnails only have to fill a grid cell in the picker.
const THUMBNAIL_WIDTH: u32 = 320;
const THUMBNAIL_QUALITY: u8 = 60;
// These are intermediate images, encoded again by WebRTC. Motion at 60 FPS uses
// a smaller JPEG so IPC and decoding do not consume the frame-time budget.
const DETAIL_FRAME_QUALITY: u8 = 85;
const MOTION_FRAME_QUALITY: u8 = 76;
/// How long to wait on an idle screen before checking whether we've been stopped.
const RECORDER_TIMEOUT: Duration = Duration::from_millis(500);
/// Keep the native producer close to the WebView consumer. Without this bound,
/// JPEG frames can accumulate in IPC and are displayed long after capture.
const MAX_IN_FLIGHT_FRAMES: usize = 2;
/// Windows below this are dialogs, tooltips and tray popups — noise in the grid.
const MIN_WINDOW_SIDE: u32 = 96;

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CaptureSource {
    /// `"screen:<id>"` or `"window:<id>"` — what `start_capture` takes back.
    id: String,
    kind: String,
    title: String,
    app_name: String,
    width: u32,
    height: u32,
    /// JPEG data URL, ready to drop into an `<img>`.
    thumbnail: String,
}

enum Target {
    Screen(u32),
    Window(u32),
}

impl Target {
    fn parse(source_id: &str) -> Result<Self, String> {
        let malformed = || format!("Malformed capture source id: {source_id}");
        let (kind, raw_id) = source_id.split_once(':').ok_or_else(malformed)?;
        let id: u32 = raw_id.parse().map_err(|_| malformed())?;
        match kind {
            "screen" => Ok(Target::Screen(id)),
            "window" => Ok(Target::Window(id)),
            other => Err(format!("Unknown capture source kind: {other}")),
        }
    }
}

struct CaptureSession {
    id: String,
    stop: AtomicBool,
    in_flight: AtomicUsize,
}

impl CaptureSession {
    fn new(id: String) -> Self {
        Self {
            id,
            stop: AtomicBool::new(false),
            in_flight: AtomicUsize::new(0),
        }
    }

    fn reserve_frame(&self) -> bool {
        self.in_flight
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current| {
                (current < MAX_IN_FLIGHT_FRAMES).then_some(current + 1)
            })
            .is_ok()
    }

    fn acknowledge_frame(&self) {
        let _ = self
            .in_flight
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current| {
                current.checked_sub(1)
            });
    }
}

/// Holds the native capture session that is currently running, if any.
/// Exactly one capture at a time: starting a second one retires the first.
#[derive(Default)]
pub struct CaptureManager {
    active: Mutex<Option<Arc<CaptureSession>>>,
}

impl CaptureManager {
    fn start(&self, session: Arc<CaptureSession>) {
        if let Ok(mut active) = self.active.lock() {
            if let Some(previous) = active.replace(session) {
                previous.stop.store(true, Ordering::Relaxed);
            }
        }
    }

    fn stop(&self, capture_id: Option<&str>) {
        if let Ok(mut active) = self.active.lock() {
            if capture_id
                .is_some_and(|id| active.as_ref().is_some_and(|session| session.id != id))
            {
                return;
            }
            if let Some(previous) = active.take() {
                previous.stop.store(true, Ordering::Relaxed);
            }
        }
    }

    fn acknowledge(&self, capture_id: &str) {
        if let Ok(active) = self.active.lock() {
            if let Some(session) = active.as_ref().filter(|session| session.id == capture_id) {
                session.acknowledge_frame();
            }
        }
    }
}

fn encode_jpeg(image: &RgbaImage, quality: u8) -> Result<Vec<u8>, String> {
    let mut buffer = Vec::new();
    // `encode_image` (not `encode`) because only it takes RGBA — the plain
    // `encode` rejects anything but L8/RGB8, and dropping alpha ourselves would
    // mean copying every frame for nothing.
    JpegEncoder::new_with_quality(&mut buffer, quality)
        .encode_image(image)
        .map_err(|error| error.to_string())?;
    Ok(buffer)
}

fn thumbnail(image: &RgbaImage) -> Result<String, String> {
    let width = THUMBNAIL_WIDTH.min(image.width()).max(1);
    let height = ((f64::from(image.height()) * f64::from(width) / f64::from(image.width().max(1)))
        .round() as u32)
        .max(1);
    let small = xcap::image::imageops::resize(image, width, height, FilterType::Triangle);
    Ok(format!(
        "data:image/jpeg;base64,{}",
        BASE64.encode(encode_jpeg(&small, THUMBNAIL_QUALITY)?)
    ))
}

fn downscale(image: RgbaImage, max_height: u32) -> RgbaImage {
    // `max_height == 0` is the picker's "native" option: ship the source as-is.
    if max_height == 0 || image.height() <= max_height {
        return image;
    }
    let width = (f64::from(image.width()) * f64::from(max_height) / f64::from(image.height()))
        .round() as u32;
    // Even dimensions: video encoders subsample chroma and dislike odd sizes.
    let width = width.max(2) & !1;
    let height = max_height & !1;
    xcap::image::imageops::resize(&image, width, height, FilterType::Triangle)
}

fn collect_sources() -> Result<Vec<CaptureSource>, String> {
    let mut sources = Vec::new();

    // Screens first — same order the picker shows its tabs in.
    for monitor in Monitor::all().map_err(|error| error.to_string())? {
        let (Ok(id), Ok(width), Ok(height)) = (monitor.id(), monitor.width(), monitor.height())
        else {
            continue;
        };
        let Ok(image) = monitor.capture_image() else {
            continue;
        };
        let name = monitor
            .friendly_name()
            .or_else(|_| monitor.name())
            .unwrap_or_else(|_| "Screen".to_string());
        sources.push(CaptureSource {
            id: format!("screen:{id}"),
            kind: "screen".to_string(),
            title: name,
            app_name: String::new(),
            width,
            height,
            thumbnail: thumbnail(&image)?,
        });
    }

    for window in Window::all().map_err(|error| error.to_string())? {
        if window.is_minimized().unwrap_or(true) {
            continue;
        }
        let (Ok(id), Ok(width), Ok(height)) = (window.id(), window.width(), window.height()) else {
            continue;
        };
        if width < MIN_WINDOW_SIDE || height < MIN_WINDOW_SIDE {
            continue;
        }
        let title = window.title().unwrap_or_default();
        if title.trim().is_empty() {
            continue;
        }
        // A window that refuses to be captured now would only fail again once
        // picked, so it's left out of the grid entirely.
        let Ok(image) = window.capture_image() else {
            continue;
        };
        sources.push(CaptureSource {
            id: format!("window:{id}"),
            kind: "window".to_string(),
            title,
            app_name: window.app_name().unwrap_or_default(),
            width,
            height,
            thumbnail: thumbnail(&image)?,
        });
    }

    Ok(sources)
}

fn send_frame(
    channel: &Channel<InvokeResponseBody>,
    image: RgbaImage,
    max_height: u32,
    quality: u8,
) -> Result<(), String> {
    let frame = encode_jpeg(&downscale(image, max_height), quality)?;
    channel
        .send(InvokeResponseBody::Raw(frame))
        .map_err(|error| error.to_string())
}

fn send_error(channel: &Channel<InvokeResponseBody>, message: &str) {
    let payload = serde_json::json!({ "error": message }).to_string();
    let _ = channel.send(InvokeResponseBody::Json(payload));
}

fn find_monitor(id: u32) -> Result<Monitor, String> {
    Monitor::all()
        .map_err(|error| error.to_string())?
        .into_iter()
        .find(|monitor| monitor.id().map(|found| found == id).unwrap_or(false))
        .ok_or_else(|| "That screen is no longer available".to_string())
}

fn find_window(id: u32) -> Result<Window, String> {
    Window::all()
        .map_err(|error| error.to_string())?
        .into_iter()
        .find(|window| window.id().map(|found| found == id).unwrap_or(false))
        .ok_or_else(|| "That window has been closed".to_string())
}

fn stream_screen(
    id: u32,
    max_height: u32,
    interval: Duration,
    quality: u8,
    session: &CaptureSession,
    channel: &Channel<InvokeResponseBody>,
) -> Result<(), String> {
    let monitor = find_monitor(id)?;
    let (recorder, frames) = monitor.video_recorder().map_err(|error| error.to_string())?;
    recorder.start().map_err(|error| error.to_string())?;

    // Always release the recorder, including failures in encoding or IPC.
    let result = (|| {
        let mut last_sent: Option<Instant> = None;
        while !session.stop.load(Ordering::Relaxed) {
            let mut frame = match frames.recv_timeout(RECORDER_TIMEOUT) {
                Ok(frame) => frame,
                // Nothing on screen changed; loop back and re-check the stop flag.
                Err(RecvTimeoutError::Timeout) => continue,
                Err(RecvTimeoutError::Disconnected) => {
                    return Err("Screen capture stopped unexpectedly".to_string());
                }
            };
            // Frames arrive at the display's refresh rate — anything above the
            // requested rate is dropped here, before the cost of encoding it.
            if last_sent.is_some_and(|at| at.elapsed() < interval) {
                continue;
            }
            if !session.reserve_frame() {
                continue;
            }
            // Encoding and IPC can briefly take longer than a display refresh. A
            // recorder queue represents old screen state, not valuable video: use
            // its newest frame so congestion reduces FPS instead of adding delay.
            for newer in frames.try_iter() {
                frame = newer;
            }
            // Include encoding time in the frame interval instead of adding it
            // on top of the interval and silently undershooting the requested FPS.
            last_sent = Some(Instant::now());
            let sent = RgbaImage::from_raw(frame.width, frame.height, frame.raw)
                .ok_or_else(|| "Capture produced a malformed frame".to_string())
                .and_then(|image| send_frame(channel, image, max_height, quality));
            if let Err(error) = sent {
                session.acknowledge_frame();
                return Err(error);
            }
        }
        Ok(())
    })();

    let _ = recorder.stop();
    result
}

fn stream_window(
    id: u32,
    max_height: u32,
    interval: Duration,
    quality: u8,
    session: &CaptureSession,
    channel: &Channel<InvokeResponseBody>,
) -> Result<(), String> {
    // Windows have no recorder in xcap, only whole-window grabs, so this side is
    // polled: the frame rate is the one the user asked for rather than the
    // display's, and a dead window surfaces as a capture error on the next tick.
    let window = find_window(id)?;

    while !session.stop.load(Ordering::Relaxed) {
        let started = Instant::now();
        if session.reserve_frame() {
            let sent = window
                .capture_image()
                .map_err(|error| error.to_string())
                .and_then(|image| send_frame(channel, image, max_height, quality));
            if let Err(error) = sent {
                session.acknowledge_frame();
                return Err(error);
            }
        }
        if let Some(remaining) = interval.checked_sub(started.elapsed()) {
            thread::sleep(remaining);
        }
    }

    Ok(())
}

#[tauri::command]
pub async fn list_capture_sources() -> Result<Vec<CaptureSource>, String> {
    // Grabbing a thumbnail of every window takes long enough to be felt, so it
    // stays off the main thread.
    tauri::async_runtime::spawn_blocking(collect_sources)
        .await
        .map_err(|error| error.to_string())?
}

#[tauri::command]
pub fn start_capture(
    manager: tauri::State<'_, CaptureManager>,
    source_id: String,
    capture_id: String,
    max_height: u32,
    fps: u32,
    on_frame: Channel<InvokeResponseBody>,
) -> Result<(), String> {
    let target = Target::parse(&source_id)?;
    let fps = fps.clamp(1, 60);
    let interval = Duration::from_secs_f64(1.0 / f64::from(fps));
    let quality = if fps > 30 {
        MOTION_FRAME_QUALITY
    } else {
        DETAIL_FRAME_QUALITY
    };
    let session = Arc::new(CaptureSession::new(capture_id));
    manager.start(session.clone());

    thread::spawn(move || {
        let result = match target {
            Target::Screen(id) => {
                stream_screen(id, max_height, interval, quality, &session, &on_frame)
            }
            Target::Window(id) => {
                stream_window(id, max_height, interval, quality, &session, &on_frame)
            }
        };
        // A capture that dies on its own — window closed, device lost — has to say
        // so: the frontend is still holding a track that nothing will feed again.
        if let Err(error) = result {
            if !session.stop.load(Ordering::Relaxed) {
                send_error(&on_frame, &error);
            }
        }
    });

    Ok(())
}

#[tauri::command]
pub fn acknowledge_capture(manager: tauri::State<'_, CaptureManager>, capture_id: String) {
    manager.acknowledge(&capture_id);
}

#[tauri::command]
pub fn stop_capture(manager: tauri::State<'_, CaptureManager>, capture_id: Option<String>) {
    manager.stop(capture_id.as_deref());
}

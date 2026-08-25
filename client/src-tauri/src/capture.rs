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
        atomic::{AtomicBool, Ordering},
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
/// WebRTC re-encodes these frames downstream, so middling quality here costs
/// little in the final picture and saves a lot of CPU and IPC traffic.
const FRAME_QUALITY: u8 = 72;
/// How long to wait on an idle screen before checking whether we've been stopped.
const RECORDER_TIMEOUT: Duration = Duration::from_millis(500);
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

/// Holds the stop flag of the capture thread that is currently running, if any.
/// Exactly one capture at a time: starting a second one retires the first.
#[derive(Default)]
pub struct CaptureManager {
    active: Mutex<Option<Arc<AtomicBool>>>,
}

impl CaptureManager {
    fn start(&self, stop: Arc<AtomicBool>) {
        if let Ok(mut active) = self.active.lock() {
            if let Some(previous) = active.replace(stop) {
                previous.store(true, Ordering::Relaxed);
            }
        }
    }

    fn stop(&self) {
        if let Ok(mut active) = self.active.lock() {
            if let Some(previous) = active.take() {
                previous.store(true, Ordering::Relaxed);
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
) -> Result<(), String> {
    let frame = encode_jpeg(&downscale(image, max_height), FRAME_QUALITY)?;
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
    stop: &AtomicBool,
    channel: &Channel<InvokeResponseBody>,
) -> Result<(), String> {
    let monitor = find_monitor(id)?;
    let (recorder, frames) = monitor.video_recorder().map_err(|error| error.to_string())?;
    recorder.start().map_err(|error| error.to_string())?;

    let mut last_sent: Option<Instant> = None;
    while !stop.load(Ordering::Relaxed) {
        let mut frame = match frames.recv_timeout(RECORDER_TIMEOUT) {
            Ok(frame) => frame,
            // Nothing on screen changed; loop back and re-check the stop flag.
            Err(RecvTimeoutError::Timeout) => continue,
            Err(RecvTimeoutError::Disconnected) => break,
        };
        // Frames arrive at the display's refresh rate — anything above the
        // requested rate is dropped here, before the cost of encoding it.
        if last_sent.is_some_and(|at| at.elapsed() < interval) {
            continue;
        }
        // Encoding and IPC can briefly take longer than a display refresh. A
        // recorder queue represents old screen state, not valuable video: use
        // its newest frame so congestion reduces FPS instead of adding delay.
        for newer in frames.try_iter() {
            frame = newer;
        }
        let image = RgbaImage::from_raw(frame.width, frame.height, frame.raw)
            .ok_or_else(|| "Capture produced a malformed frame".to_string())?;
        send_frame(channel, image, max_height)?;
        last_sent = Some(Instant::now());
    }

    let _ = recorder.stop();
    Ok(())
}

fn stream_window(
    id: u32,
    max_height: u32,
    interval: Duration,
    stop: &AtomicBool,
    channel: &Channel<InvokeResponseBody>,
) -> Result<(), String> {
    // Windows have no recorder in xcap, only whole-window grabs, so this side is
    // polled: the frame rate is the one the user asked for rather than the
    // display's, and a dead window surfaces as a capture error on the next tick.
    let window = find_window(id)?;

    while !stop.load(Ordering::Relaxed) {
        let started = Instant::now();
        let image = window.capture_image().map_err(|error| error.to_string())?;
        send_frame(channel, image, max_height)?;
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
    max_height: u32,
    fps: u32,
    on_frame: Channel<InvokeResponseBody>,
) -> Result<(), String> {
    let target = Target::parse(&source_id)?;
    let interval = Duration::from_secs_f64(1.0 / f64::from(fps.clamp(1, 60)));
    let stop = Arc::new(AtomicBool::new(false));
    manager.start(stop.clone());

    thread::spawn(move || {
        let result = match target {
            Target::Screen(id) => stream_screen(id, max_height, interval, &stop, &on_frame),
            Target::Window(id) => stream_window(id, max_height, interval, &stop, &on_frame),
        };
        // A capture that dies on its own — window closed, device lost — has to say
        // so: the frontend is still holding a track that nothing will feed again.
        if let Err(error) = result {
            if !stop.load(Ordering::Relaxed) {
                send_error(&on_frame, &error);
            }
        }
    });

    Ok(())
}

#[tauri::command]
pub fn stop_capture(manager: tauri::State<'_, CaptureManager>) {
    manager.stop();
}

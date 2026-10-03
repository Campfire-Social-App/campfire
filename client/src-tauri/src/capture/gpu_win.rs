//! GPU screen capture and H.264 encode for Windows.
//!
//! The CPU path in the parent module reads frames back into RGBA, resizes them
//! with a generic filter and JPEG-encodes every one — measured at 65-99 ms per
//! frame in production, which capped screen share at 10-13 FPS no matter what
//! the user asked for. Here the frame never leaves the GPU until it is already
//! compressed: Windows.Graphics.Capture yields a D3D11 texture, the D3D11 video
//! processor scales it and converts BGRA to NV12, and a Media Foundation
//! transform encodes H.264. Only the bitstream crosses to the frontend, which
//! also keeps us far below the ~50 MB/s Tauri IPC can sustain on Windows —
//! raw NV12 frames would need 41-93 MB/s and never fit.

use std::{
    collections::VecDeque,
    ffi::c_void,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    mem::ManuallyDrop,
    thread,
    time::{Duration, Instant},
};

use windows::{
    core::{Interface, HSTRING},
    Foundation::{Metadata::ApiInformation, TypedEventHandler},
    Graphics::{
        Capture::{Direct3D11CaptureFramePool, GraphicsCaptureItem},
        DirectX::{Direct3D11::IDirect3DDevice, DirectXPixelFormat},
        SizeInt32,
    },
    Win32::{
        Foundation::{HMODULE, HWND, LPARAM, RECT, VARIANT_BOOL},
        Graphics::{
            Direct3D::{D3D_DRIVER_TYPE_HARDWARE, D3D_FEATURE_LEVEL_11_0},
            Direct3D11::{
                D3D11CreateDevice, ID3D11Device, ID3D11DeviceContext, ID3D11Multithread,
                ID3D11Texture2D, ID3D11VideoContext1, ID3D11VideoDevice, ID3D11VideoProcessor,
                ID3D11VideoProcessorEnumerator, ID3D11VideoProcessorOutputView,
                D3D11_BIND_RENDER_TARGET, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                D3D11_CREATE_DEVICE_VIDEO_SUPPORT, D3D11_SDK_VERSION, D3D11_TEX2D_VPIV,
                D3D11_TEX2D_VPOV, D3D11_TEXTURE2D_DESC, D3D11_USAGE_DEFAULT,
                D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE, D3D11_VIDEO_PROCESSOR_CONTENT_DESC,
                D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC, D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC_0,
                D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC, D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC_0,
                D3D11_VIDEO_PROCESSOR_STREAM, D3D11_VIDEO_USAGE_OPTIMAL_SPEED,
                D3D11_VPIV_DIMENSION_TEXTURE2D, D3D11_VPOV_DIMENSION_TEXTURE2D,
            },
            Dxgi::{
                Common::{
                    DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709,
                    DXGI_COLOR_SPACE_YCBCR_STUDIO_G22_LEFT_P709, DXGI_FORMAT_NV12, DXGI_RATIONAL,
                    DXGI_SAMPLE_DESC,
                },
                IDXGIDevice,
            },
            Gdi::{EnumDisplayMonitors, HDC, HMONITOR},
        },
        Media::MediaFoundation::{
            IMF2DBuffer, IMFActivate, IMFDXGIDeviceManager, IMFMediaEventGenerator, IMFTransform,
            MFCreateDXGIDeviceManager, MFCreateDXGISurfaceBuffer, MFCreateMediaType,
            MFCreateSample, MFShutdown, MFStartup, MFTEnumEx, MFSampleExtension_CleanPoint,
            MFT_OUTPUT_DATA_BUFFER, MFT_REGISTER_TYPE_INFO, MFMediaType_Video,
            MFVideoFormat_H264, MFVideoFormat_NV12, MFVideoInterlace_Progressive,
            MF_EVENT_TYPE, MF_E_NO_EVENTS_AVAILABLE, MF_E_TRANSFORM_NEED_MORE_INPUT,
            MF_EVENT_FLAG_NO_WAIT, MF_LOW_LATENCY, MF_MT_AVG_BITRATE, MF_MT_FRAME_RATE,
            MF_MT_FRAME_SIZE, MF_MT_INTERLACE_MODE, MF_MT_MAJOR_TYPE, MF_MT_MPEG2_PROFILE,
            MF_MT_MPEG_SEQUENCE_HEADER, MF_MT_PIXEL_ASPECT_RATIO, MF_MT_SUBTYPE,
            MF_TRANSFORM_ASYNC_UNLOCK, MF_VERSION, MFSTARTUP_NOSOCKET,
            MFT_CATEGORY_VIDEO_ENCODER, MFT_ENUM_FLAG_HARDWARE, MFT_ENUM_FLAG_SORTANDFILTER,
            MFT_FRIENDLY_NAME_Attribute, MFT_MESSAGE_NOTIFY_BEGIN_STREAMING,
            MFT_MESSAGE_NOTIFY_END_OF_STREAM, MFT_MESSAGE_NOTIFY_END_STREAMING,
            MFT_MESSAGE_NOTIFY_START_OF_STREAM, MFT_MESSAGE_SET_D3D_MANAGER, METransformHaveOutput,
            METransformNeedInput, ICodecAPI, CODECAPI_AVEncCommonLowLatency,
            CODECAPI_AVEncCommonMeanBitRate, CODECAPI_AVEncCommonRateControlMode,
            CODECAPI_AVEncMPVDefaultBPictureCount, CODECAPI_AVEncMPVGOPSize,
            CODECAPI_AVEncVideoForceKeyFrame, eAVEncCommonRateControlMode_CBR,
            eAVEncH264VProfile_High,
        },
        System::{
            Com::CoTaskMemFree,
            Variant::{VARIANT, VT_BOOL, VT_UI4},
            WinRT::{
                Direct3D11::{
                    CreateDirect3D11DeviceFromDXGIDevice, IDirect3DDxgiInterfaceAccess,
                },
                Graphics::Capture::IGraphicsCaptureItemInterop,
            },
        },
        UI::WindowsAndMessaging::{EnumWindows, IsWindowVisible},
    },
};

/// Why the GPU path could not run. Both variants fall back to the CPU path;
/// they are kept apart so the log says whether this machine can never do it
/// (no hardware encoder) or whether something failed that might be transient.
#[derive(Debug)]
pub enum GpuError {
    Unsupported(String),
    Failed(String),
}

impl GpuError {
    pub fn reason(&self) -> &str {
        match self {
            GpuError::Unsupported(reason) | GpuError::Failed(reason) => reason,
        }
    }

    pub fn kind(&self) -> &'static str {
        match self {
            GpuError::Unsupported(_) => "unsupported",
            GpuError::Failed(_) => "failed",
        }
    }
}

pub type GpuResult<T> = Result<T, GpuError>;

/// `windows::core::Error` carries the HRESULT, which is the only part worth
/// logging — the message is usually "The operation completed successfully".
fn failed(context: &str) -> impl Fn(windows::core::Error) -> GpuError + '_ {
    move |error| GpuError::Failed(format!("{context}: {} ({})", error.message(), error.code().0))
}

fn unsupported(context: &str) -> impl Fn(windows::core::Error) -> GpuError + '_ {
    move |error| {
        GpuError::Unsupported(format!("{context}: {} ({})", error.message(), error.code().0))
    }
}

/// What the picker asked for, resolved into encoder terms.
pub struct GpuConfig {
    /// 0 keeps the source resolution (the picker's "native" option).
    pub max_height: u32,
    pub fps: u32,
    /// The intermediate stream only has to survive local IPC, so this is far
    /// above what the call will actually send: it keeps the double encode
    /// (ours, then the WebView's) visually free.
    pub bitrate: u32,
    pub frame_interval: Duration,
}

impl GpuConfig {
    pub fn new(max_height: u32, fps: u32, game_mode: bool) -> Self {
        let fps = fps.clamp(1, 60);
        Self {
            max_height,
            fps,
            // Game content changes every pixel every frame; desktop content
            // does not, and spending less here leaves more IPC headroom.
            bitrate: if game_mode { 50_000_000 } else { 25_000_000 },
            frame_interval: Duration::from_secs_f64(1.0 / f64::from(fps)),
        }
    }
}

/// The D3D11 device shared by capture, scaling and the encoder, plus the
/// Media Foundation wrapper the encoder needs to accept GPU textures.
pub struct GpuDevice {
    pub device: ID3D11Device,
    pub context: ID3D11DeviceContext,
    /// WinRT projection of the same device — what the capture frame pool takes.
    pub winrt_device: IDirect3DDevice,
    pub mf_manager: IMFDXGIDeviceManager,
}

impl GpuDevice {
    pub fn new() -> GpuResult<Self> {
        let mut device: Option<ID3D11Device> = None;
        let mut context: Option<ID3D11DeviceContext> = None;
        unsafe {
            D3D11CreateDevice(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                HMODULE::default(),
                // BGRA for the capture surfaces, VIDEO for the video processor
                // and for the encoder to accept our textures at all.
                D3D11_CREATE_DEVICE_BGRA_SUPPORT | D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
                Some(&[D3D_FEATURE_LEVEL_11_0]),
                D3D11_SDK_VERSION,
                Some(&mut device),
                None,
                Some(&mut context),
            )
        }
        .map_err(unsupported("D3D11CreateDevice"))?;

        let device = device.ok_or_else(|| GpuError::Unsupported("No D3D11 device".into()))?;
        let context = context.ok_or_else(|| GpuError::Unsupported("No D3D11 context".into()))?;

        // The encoder calls into this device from its own worker threads, so
        // without this every ProcessInput races the capture thread's Blt.
        let multithread: ID3D11Multithread =
            device.cast().map_err(failed("ID3D11Multithread cast"))?;
        let _ = unsafe { multithread.SetMultithreadProtected(true) };

        let dxgi_device: IDXGIDevice = device.cast().map_err(failed("IDXGIDevice cast"))?;
        let winrt_device = unsafe { CreateDirect3D11DeviceFromDXGIDevice(&dxgi_device) }
            .map_err(failed("CreateDirect3D11DeviceFromDXGIDevice"))?
            .cast::<IDirect3DDevice>()
            .map_err(failed("IDirect3DDevice cast"))?;

        let mut reset_token = 0u32;
        let mut mf_manager: Option<IMFDXGIDeviceManager> = None;
        unsafe { MFCreateDXGIDeviceManager(&mut reset_token, &mut mf_manager) }
            .map_err(failed("MFCreateDXGIDeviceManager"))?;
        let mf_manager =
            mf_manager.ok_or_else(|| GpuError::Failed("No MF device manager".into()))?;
        unsafe { mf_manager.ResetDevice(&device, reset_token) }
            .map_err(failed("IMFDXGIDeviceManager::ResetDevice"))?;

        Ok(Self {
            device,
            context,
            winrt_device,
            mf_manager,
        })
    }
}

/// Even dimensions, because NV12 subsamples chroma and both the video
/// processor and the encoder reject odd sizes. `max_height == 0` is the
/// picker's "native" option — keep the source resolution.
pub fn target_size(source: (u32, u32), max_height: u32) -> (u32, u32) {
    let (width, height) = source;
    if max_height == 0 || height <= max_height {
        return (width.max(2) & !1, height.max(2) & !1);
    }
    let scaled = (f64::from(width) * f64::from(max_height) / f64::from(height.max(1))).round() as u32;
    (scaled.max(2) & !1, max_height.max(2) & !1)
}

/// Scales the captured BGRA texture and converts it to NV12, entirely on the
/// GPU. The output resolution is fixed for the life of the session: when the
/// captured window is resized the source rectangle changes instead, so the
/// encoder never has to be rebuilt (and the stream never has to be
/// renegotiated with the decoder on the other side of the IPC).
pub struct Scaler {
    video_device: ID3D11VideoDevice,
    video_context: ID3D11VideoContext1,
    enumerator: ID3D11VideoProcessorEnumerator,
    processor: ID3D11VideoProcessor,
    textures: Vec<ID3D11Texture2D>,
    views: Vec<ID3D11VideoProcessorOutputView>,
    next: usize,
    source: (u32, u32),
    pub width: u32,
    pub height: u32,
}

/// Enough NV12 surfaces that the encoder can still hold one while we write the
/// next, without ever allocating on the capture path.
const OUTPUT_RING: usize = 3;

impl Scaler {
    pub fn new(gpu: &GpuDevice, source: (u32, u32), output: (u32, u32)) -> GpuResult<Self> {
        let video_device: ID3D11VideoDevice =
            gpu.device.cast().map_err(unsupported("ID3D11VideoDevice"))?;
        let video_context: ID3D11VideoContext1 = gpu
            .context
            .cast()
            .map_err(unsupported("ID3D11VideoContext1"))?;

        let rate = DXGI_RATIONAL {
            Numerator: 60,
            Denominator: 1,
        };
        let content = D3D11_VIDEO_PROCESSOR_CONTENT_DESC {
            InputFrameFormat: D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE,
            InputFrameRate: rate,
            InputWidth: source.0,
            InputHeight: source.1,
            OutputFrameRate: rate,
            OutputWidth: output.0,
            OutputHeight: output.1,
            // Real-time: prefer speed over the quality-oriented filters.
            Usage: D3D11_VIDEO_USAGE_OPTIMAL_SPEED,
        };
        let enumerator = unsafe { video_device.CreateVideoProcessorEnumerator(&content) }
            .map_err(unsupported("CreateVideoProcessorEnumerator"))?;
        let processor = unsafe { video_device.CreateVideoProcessor(&enumerator, 0) }
            .map_err(unsupported("CreateVideoProcessor"))?;

        let mut textures = Vec::with_capacity(OUTPUT_RING);
        let mut views = Vec::with_capacity(OUTPUT_RING);
        let desc = D3D11_TEXTURE2D_DESC {
            Width: output.0,
            Height: output.1,
            MipLevels: 1,
            ArraySize: 1,
            Format: DXGI_FORMAT_NV12,
            SampleDesc: DXGI_SAMPLE_DESC {
                Count: 1,
                Quality: 0,
            },
            Usage: D3D11_USAGE_DEFAULT,
            BindFlags: D3D11_BIND_RENDER_TARGET.0 as u32,
            CPUAccessFlags: 0,
            MiscFlags: 0,
        };
        for _ in 0..OUTPUT_RING {
            let mut texture: Option<ID3D11Texture2D> = None;
            unsafe { gpu.device.CreateTexture2D(&desc, None, Some(&mut texture)) }
                .map_err(unsupported("CreateTexture2D(NV12)"))?;
            let texture =
                texture.ok_or_else(|| GpuError::Failed("No NV12 texture created".into()))?;
            let view_desc = D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC {
                ViewDimension: D3D11_VPOV_DIMENSION_TEXTURE2D,
                Anonymous: D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC_0 {
                    Texture2D: D3D11_TEX2D_VPOV { MipSlice: 0 },
                },
            };
            let mut view: Option<ID3D11VideoProcessorOutputView> = None;
            unsafe {
                video_device.CreateVideoProcessorOutputView(
                    &texture,
                    &enumerator,
                    &view_desc,
                    Some(&mut view),
                )
            }
            .map_err(failed("CreateVideoProcessorOutputView"))?;
            views.push(view.ok_or_else(|| GpuError::Failed("No output view created".into()))?);
            textures.push(texture);
        }

        let scaler = Self {
            video_device,
            video_context,
            enumerator,
            processor,
            textures,
            views,
            next: 0,
            source,
            width: output.0,
            height: output.1,
        };

        // Leaving these at their defaults is the classic washed-out /
        // crushed-blacks bug: the processor would guess, and guess differently
        // per driver. The capture surfaces are full-range sRGB; H.264 expects
        // studio-range BT.709.
        unsafe {
            scaler.video_context.VideoProcessorSetStreamColorSpace1(
                &scaler.processor,
                0,
                DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709,
            );
            scaler.video_context.VideoProcessorSetOutputColorSpace1(
                &scaler.processor,
                DXGI_COLOR_SPACE_YCBCR_STUDIO_G22_LEFT_P709,
            );
        }
        scaler.fit_source();
        Ok(scaler)
    }

    /// Maps the source into the fixed output, preserving aspect ratio and
    /// letterboxing the remainder, so a window that is resized mid-share
    /// neither stretches nor forces a stream reconfiguration.
    fn fit_source(&self) {
        let (source_width, source_height) = self.source;
        let scale = f64::from(self.width) / f64::from(source_width.max(1));
        let scale = scale.min(f64::from(self.height) / f64::from(source_height.max(1)));
        let width = ((f64::from(source_width) * scale).round() as u32).clamp(2, self.width) & !1;
        let height = ((f64::from(source_height) * scale).round() as u32).clamp(2, self.height) & !1;
        let left = ((self.width - width) / 2) as i32;
        let top = ((self.height - height) / 2) as i32;
        let source_rect = RECT {
            left: 0,
            top: 0,
            right: source_width as i32,
            bottom: source_height as i32,
        };
        let dest_rect = RECT {
            left,
            top,
            right: left + width as i32,
            bottom: top + height as i32,
        };
        unsafe {
            self.video_context
                .VideoProcessorSetStreamSourceRect(&self.processor, 0, true, Some(&source_rect));
            self.video_context
                .VideoProcessorSetStreamDestRect(&self.processor, 0, true, Some(&dest_rect));
        }
    }

    /// Converts one captured texture. The returned NV12 texture belongs to the
    /// ring and stays valid until it comes around again.
    pub fn convert(
        &mut self,
        frame: &ID3D11Texture2D,
        source: (u32, u32),
    ) -> GpuResult<ID3D11Texture2D> {
        if source != self.source {
            self.source = source;
            self.fit_source();
        }

        // The input view is per-frame because every captured frame is a
        // different texture out of the capture pool.
        let view_desc = D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC {
            FourCC: 0,
            ViewDimension: D3D11_VPIV_DIMENSION_TEXTURE2D,
            Anonymous: D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC_0 {
                Texture2D: D3D11_TEX2D_VPIV {
                    MipSlice: 0,
                    ArraySlice: 0,
                },
            },
        };
        let mut input_view = None;
        unsafe {
            self.video_device.CreateVideoProcessorInputView(
                frame,
                &self.enumerator,
                &view_desc,
                Some(&mut input_view),
            )
        }
        .map_err(failed("CreateVideoProcessorInputView"))?;
        let input_view = input_view.ok_or_else(|| GpuError::Failed("No input view".into()))?;

        let slot = self.next;
        self.next = (self.next + 1) % self.textures.len();

        // `pInputSurface` is a ManuallyDrop field, so the view is moved in and
        // taken back out below: no reference is leaked and none is released
        // while the blit is still reading it.
        let stream = D3D11_VIDEO_PROCESSOR_STREAM {
            Enable: true.into(),
            pInputSurface: ManuallyDrop::new(Some(input_view)),
            ..Default::default()
        };
        let blt = unsafe {
            self.video_context.VideoProcessorBlt(
                &self.processor,
                &self.views[slot],
                0,
                std::slice::from_ref(&stream),
            )
        };
        drop(ManuallyDrop::into_inner(stream.pInputSurface));
        blt.map_err(failed("VideoProcessorBlt"))?;

        Ok(self.textures[slot].clone())
    }
}

/// Media Foundation is per-process but refcounted; calling this on every
/// capture start is correct and cheap.
pub fn start_media_foundation() -> GpuResult<()> {
    unsafe { MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET) }.map_err(unsupported("MFStartup"))
}

/// Media Foundation packs paired 32-bit values (size, frame rate, aspect
/// ratio) into one 64-bit attribute.
fn pack(high: u32, low: u32) -> u64 {
    (u64::from(high) << 32) | u64::from(low)
}

fn variant_u32(value: u32) -> VARIANT {
    let mut variant = VARIANT::default();
    unsafe {
        let inner = &mut *variant.Anonymous.Anonymous;
        inner.vt = VT_UI4;
        inner.Anonymous.ulVal = value;
    }
    variant
}

fn variant_bool(value: bool) -> VARIANT {
    let mut variant = VARIANT::default();
    unsafe {
        let inner = &mut *variant.Anonymous.Anonymous;
        inner.vt = VT_BOOL;
        inner.Anonymous.boolVal = VARIANT_BOOL(if value { -1 } else { 0 });
    }
    variant
}

/// One compressed access unit, ready to ship to the frontend.
pub struct EncodedFrame {
    pub data: Vec<u8>,
    pub keyframe: bool,
    pub timestamp_us: u64,
}

/// The async MFT protocol: it tells us when it wants a frame and when one is
/// ready, and calling `ProcessInput`/`ProcessOutput` out of turn is an error.
pub enum EncoderEvent {
    NeedInput,
    HaveOutput,
}

/// Hardware H.264 encoder. The samples we feed it are GPU textures, so the
/// pixels never touch the CPU before they are compressed.
pub struct Encoder {
    transform: IMFTransform,
    codec_api: Option<ICodecAPI>,
    events: IMFMediaEventGenerator,
    /// Which vendor's encoder we got — the single most useful thing in the log
    /// when someone reports bad quality or low FPS on unfamiliar hardware.
    pub name: String,
    /// SPS/PPS for the stream. The decoder on the other side also gets them
    /// in-band with every keyframe, but having them up front lets it build an
    /// exact codec string.
    pub parameter_sets: Vec<u8>,
    /// Which `ICodecAPI` knobs the driver actually accepted.
    pub tuned: Vec<&'static str>,
    duration_100ns: i64,
}

impl Encoder {
    pub fn new(gpu: &GpuDevice, width: u32, height: u32, config: &GpuConfig) -> GpuResult<Self> {
        let input_info = MFT_REGISTER_TYPE_INFO {
            guidMajorType: MFMediaType_Video,
            guidSubtype: MFVideoFormat_NV12,
        };
        let output_info = MFT_REGISTER_TYPE_INFO {
            guidMajorType: MFMediaType_Video,
            guidSubtype: MFVideoFormat_H264,
        };
        let mut activates: *mut Option<IMFActivate> = std::ptr::null_mut();
        let mut count = 0u32;
        unsafe {
            MFTEnumEx(
                MFT_CATEGORY_VIDEO_ENCODER,
                // HARDWARE only: a software H.264 encoder here would just be
                // the JPEG problem again under a different name, and the CPU
                // fallback path already covers that case better.
                MFT_ENUM_FLAG_HARDWARE | MFT_ENUM_FLAG_SORTANDFILTER,
                Some(&input_info),
                Some(&output_info),
                &mut activates,
                &mut count,
            )
        }
        .map_err(unsupported("MFTEnumEx"))?;

        let mut chosen: Option<(IMFTransform, String)> = None;
        if !activates.is_null() {
            let list = unsafe { std::slice::from_raw_parts_mut(activates, count as usize) };
            for slot in list.iter_mut() {
                // Taking the value transfers ownership here, so the reference
                // is released when it goes out of scope.
                let Some(activate) = slot.take() else { continue };
                if chosen.is_some() {
                    continue;
                }
                let name = activate_name(&activate);
                if let Ok(transform) = unsafe { activate.ActivateObject::<IMFTransform>() } {
                    chosen = Some((transform, name));
                }
            }
            unsafe { CoTaskMemFree(Some(activates as *const c_void)) };
        }
        let (transform, name) = chosen.ok_or_else(|| {
            GpuError::Unsupported("No hardware H.264 encoder on this system".into())
        })?;

        // Async unlock has to happen before any type is set, and the encoder
        // stays in synchronous mode (and rejects our event loop) without it.
        let attributes = unsafe { transform.GetAttributes() }
            .map_err(unsupported("IMFTransform::GetAttributes"))?;
        unsafe { attributes.SetUINT32(&MF_TRANSFORM_ASYNC_UNLOCK, 1) }
            .map_err(unsupported("MF_TRANSFORM_ASYNC_UNLOCK"))?;
        let _ = unsafe { attributes.SetUINT32(&MF_LOW_LATENCY, 1) };

        unsafe {
            transform.ProcessMessage(
                MFT_MESSAGE_SET_D3D_MANAGER,
                Interface::as_raw(&gpu.mf_manager) as usize,
            )
        }
        .map_err(unsupported("MFT_MESSAGE_SET_D3D_MANAGER"))?;

        // Output type first: the encoder derives what inputs it will accept
        // from what it has been asked to produce.
        let output_type = unsafe { MFCreateMediaType() }.map_err(failed("MFCreateMediaType"))?;
        unsafe {
            output_type
                .SetGUID(&MF_MT_MAJOR_TYPE, &MFMediaType_Video)
                .and_then(|()| output_type.SetGUID(&MF_MT_SUBTYPE, &MFVideoFormat_H264))
                .and_then(|()| output_type.SetUINT32(&MF_MT_AVG_BITRATE, config.bitrate))
                .and_then(|()| output_type.SetUINT64(&MF_MT_FRAME_SIZE, pack(width, height)))
                .and_then(|()| output_type.SetUINT64(&MF_MT_FRAME_RATE, pack(config.fps, 1)))
                .and_then(|()| output_type.SetUINT64(&MF_MT_PIXEL_ASPECT_RATIO, pack(1, 1)))
                .and_then(|()| {
                    output_type.SetUINT32(
                        &MF_MT_INTERLACE_MODE,
                        MFVideoInterlace_Progressive.0 as u32,
                    )
                })
                .and_then(|()| {
                    output_type.SetUINT32(&MF_MT_MPEG2_PROFILE, eAVEncH264VProfile_High.0 as u32)
                })
        }
        .map_err(failed("H.264 output type"))?;
        unsafe { transform.SetOutputType(0, &output_type, 0) }
            .map_err(unsupported("SetOutputType(H264)"))?;

        let input_type = unsafe { MFCreateMediaType() }.map_err(failed("MFCreateMediaType"))?;
        unsafe {
            input_type
                .SetGUID(&MF_MT_MAJOR_TYPE, &MFMediaType_Video)
                .and_then(|()| input_type.SetGUID(&MF_MT_SUBTYPE, &MFVideoFormat_NV12))
                .and_then(|()| input_type.SetUINT64(&MF_MT_FRAME_SIZE, pack(width, height)))
                .and_then(|()| input_type.SetUINT64(&MF_MT_FRAME_RATE, pack(config.fps, 1)))
                .and_then(|()| {
                    input_type
                        .SetUINT32(&MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive.0 as u32)
                })
        }
        .map_err(failed("NV12 input type"))?;
        unsafe { transform.SetInputType(0, &input_type, 0) }
            .map_err(unsupported("SetInputType(NV12)"))?;

        let codec_api = transform.cast::<ICodecAPI>().ok();
        let mut tuned = Vec::new();
        if let Some(api) = &codec_api {
            // Every one of these is advisory: support varies by vendor and a
            // rejection is normal, so we record what stuck instead of failing.
            let knobs: [(&'static str, windows::core::GUID, VARIANT); 5] = [
                (
                    "rate_control_cbr",
                    CODECAPI_AVEncCommonRateControlMode,
                    variant_u32(eAVEncCommonRateControlMode_CBR.0 as u32),
                ),
                (
                    "mean_bitrate",
                    CODECAPI_AVEncCommonMeanBitRate,
                    variant_u32(config.bitrate),
                ),
                // B-frames reorder output, which costs latency for nothing in
                // a real-time stream.
                (
                    "no_b_frames",
                    CODECAPI_AVEncMPVDefaultBPictureCount,
                    variant_u32(0),
                ),
                ("low_latency", CODECAPI_AVEncCommonLowLatency, variant_bool(true)),
                // Long GOP: the WebView re-encodes anyway, so keyframes here
                // only cost bitrate. Recovery is driven on demand instead.
                (
                    "gop_size",
                    CODECAPI_AVEncMPVGOPSize,
                    variant_u32(config.fps.saturating_mul(4).max(1)),
                ),
            ];
            for (label, guid, value) in knobs {
                if unsafe { api.SetValue(&guid, &value) }.is_ok() {
                    tuned.push(label);
                }
            }
        }

        let events = transform
            .cast::<IMFMediaEventGenerator>()
            .map_err(unsupported("IMFMediaEventGenerator"))?;

        unsafe {
            transform
                .ProcessMessage(MFT_MESSAGE_NOTIFY_BEGIN_STREAMING, 0)
                .and_then(|()| transform.ProcessMessage(MFT_MESSAGE_NOTIFY_START_OF_STREAM, 0))
        }
        .map_err(failed("NOTIFY_BEGIN_STREAMING"))?;

        Ok(Self {
            transform,
            codec_api,
            events,
            name,
            parameter_sets: Vec::new(),
            tuned,
            duration_100ns: (10_000_000 / i64::from(config.fps.max(1))).max(1),
        })
    }

    /// Non-blocking: the caller polls this alongside the capture pool so one
    /// thread can drive both without cross-thread COM marshalling.
    pub fn poll_event(&self) -> GpuResult<Option<EncoderEvent>> {
        let event = match unsafe { self.events.GetEvent(MF_EVENT_FLAG_NO_WAIT) } {
            Ok(event) => event,
            Err(error) if error.code() == MF_E_NO_EVENTS_AVAILABLE => return Ok(None),
            Err(error) => return Err(failed("IMFMediaEventGenerator::GetEvent")(error)),
        };
        let kind = unsafe { event.GetType() }.map_err(failed("IMFMediaEvent::GetType"))?;
        Ok(match MF_EVENT_TYPE(kind as i32) {
            t if t == METransformNeedInput => Some(EncoderEvent::NeedInput),
            t if t == METransformHaveOutput => Some(EncoderEvent::HaveOutput),
            _ => None,
        })
    }

    /// Hands one NV12 texture to the encoder. Only legal after a `NeedInput`.
    pub fn submit(&self, texture: &ID3D11Texture2D, time_100ns: i64) -> GpuResult<()> {
        let buffer = unsafe {
            MFCreateDXGISurfaceBuffer(&ID3D11Texture2D::IID, texture, 0, false)
                .map_err(failed("MFCreateDXGISurfaceBuffer"))?
        };
        // A DXGI buffer starts out with zero length; the encoder reads
        // nothing unless we declare how much of it is valid.
        let length = unsafe {
            buffer
                .cast::<IMF2DBuffer>()
                .map_err(failed("IMF2DBuffer"))?
                .GetContiguousLength()
                .map_err(failed("GetContiguousLength"))?
        };
        unsafe { buffer.SetCurrentLength(length) }.map_err(failed("SetCurrentLength"))?;

        let sample = unsafe { MFCreateSample() }.map_err(failed("MFCreateSample"))?;
        unsafe {
            sample
                .AddBuffer(&buffer)
                .and_then(|()| sample.SetSampleTime(time_100ns))
                .and_then(|()| sample.SetSampleDuration(self.duration_100ns))
        }
        .map_err(failed("IMFSample setup"))?;

        unsafe { self.transform.ProcessInput(0, &sample, 0) }
            .map_err(failed("IMFTransform::ProcessInput"))
    }

    /// Collects one encoded access unit. Only legal after a `HaveOutput`.
    pub fn take_output(&mut self) -> GpuResult<Option<EncodedFrame>> {
        let mut buffers = [MFT_OUTPUT_DATA_BUFFER {
            dwStreamID: 0,
            pSample: ManuallyDrop::new(None),
            dwStatus: 0,
            pEvents: ManuallyDrop::new(None),
        }];
        let mut status = 0u32;
        let result = unsafe { self.transform.ProcessOutput(0, &mut buffers, &mut status) };
        // A hardware MFT allocates its own output sample, so take ownership of
        // whatever it left behind before looking at the result.
        let sample =
            ManuallyDrop::into_inner(std::mem::replace(&mut buffers[0].pSample, ManuallyDrop::new(None)));
        let _ = ManuallyDrop::into_inner(std::mem::replace(
            &mut buffers[0].pEvents,
            ManuallyDrop::new(None),
        ));
        match result {
            Ok(()) => {}
            Err(error) if error.code() == MF_E_TRANSFORM_NEED_MORE_INPUT => return Ok(None),
            Err(error) => return Err(failed("IMFTransform::ProcessOutput")(error)),
        }
        let Some(sample) = sample else { return Ok(None) };

        if self.parameter_sets.is_empty() {
            self.parameter_sets = self.read_parameter_sets();
        }

        let keyframe = unsafe { sample.GetUINT32(&MFSampleExtension_CleanPoint) }.unwrap_or(0) != 0;
        let time_100ns = unsafe { sample.GetSampleTime() }.unwrap_or(0).max(0);
        let buffer = unsafe { sample.ConvertToContiguousBuffer() }
            .map_err(failed("ConvertToContiguousBuffer"))?;

        let mut pointer = std::ptr::null_mut();
        let mut length = 0u32;
        unsafe { buffer.Lock(&mut pointer, None, Some(&mut length)) }
            .map_err(failed("IMFMediaBuffer::Lock"))?;
        let data = unsafe { std::slice::from_raw_parts(pointer, length as usize) }.to_vec();
        let _ = unsafe { buffer.Unlock() };

        Ok(Some(EncodedFrame {
            data,
            keyframe,
            // 100ns units to microseconds, which is what WebCodecs wants.
            timestamp_us: (time_100ns / 10) as u64,
        }))
    }

    /// SPS/PPS, available only once the output type has been negotiated —
    /// which for most encoders is after the first frame comes out.
    fn read_parameter_sets(&self) -> Vec<u8> {
        let Ok(media_type) = (unsafe { self.transform.GetOutputCurrentType(0) }) else {
            return Vec::new();
        };
        let Ok(size) = (unsafe { media_type.GetBlobSize(&MF_MT_MPEG_SEQUENCE_HEADER) }) else {
            return Vec::new();
        };
        let mut blob = vec![0u8; size as usize];
        match unsafe { media_type.GetBlob(&MF_MT_MPEG_SEQUENCE_HEADER, &mut blob, None) } {
            Ok(()) => blob,
            Err(_) => Vec::new(),
        }
    }

    /// Asks for an IDR on the next frame — the recovery path when the decoder
    /// on the frontend side loses sync.
    pub fn force_keyframe(&self) -> bool {
        let Some(api) = &self.codec_api else {
            return false;
        };
        let value = variant_bool(true);
        unsafe { api.SetValue(&CODECAPI_AVEncVideoForceKeyFrame, &value) }.is_ok()
    }
}

impl Drop for Encoder {
    fn drop(&mut self) {
        unsafe {
            let _ = self
                .transform
                .ProcessMessage(MFT_MESSAGE_NOTIFY_END_OF_STREAM, 0);
            let _ = self
                .transform
                .ProcessMessage(MFT_MESSAGE_NOTIFY_END_STREAMING, 0);
        }
    }
}

/// What `stream` reports back for each access unit it produces, plus the
/// per-stage timings the log needs to tell capture, scaling, encoding and IPC
/// apart the way `FrameStats` does for the CPU path.
pub struct GpuFrame {
    pub encoded: EncodedFrame,
    pub width: u32,
    pub height: u32,
    /// SPS/PPS, present on the first frame of the stream and after a forced
    /// recovery — the frontend uses it to (re)configure its decoder.
    pub config: Option<Vec<u8>>,
    pub scale_ms: f64,
    pub encode_ms: f64,
}

/// Why the capture loop stopped, so the caller can tell "the user stopped it"
/// apart from "the window closed" apart from "the GPU went away".
pub enum GpuStop {
    Stopped,
    SourceClosed,
    DeviceLost,
}

/// Everything the loop needs from the owner: whether to keep going, and where
/// to put the frames it produces.
pub trait GpuSink {
    fn keep_going(&self) -> bool;
    /// The frontend is behind. Capture pauses — output is never dropped,
    /// because a missing access unit corrupts the stream until the next
    /// keyframe.
    fn congested(&self) -> bool;
    /// `false` asks the loop to stop (the frontend went away).
    fn frame(&mut self, frame: GpuFrame) -> bool;
    /// Polled each iteration: the frontend's decoder lost sync and needs an IDR.
    fn keyframe_requested(&mut self) -> bool;
    fn dropped_stale(&mut self, count: u32);
    fn starved(&mut self);
}

/// Capture pool depth. Two is enough to never miss a frame while we encode the
/// previous one, and keeps the backlog (and so the latency) short.
const POOL_BUFFERS: i32 = 2;

pub fn stream(
    target: CaptureTarget,
    config: &GpuConfig,
    sink: &mut dyn GpuSink,
) -> GpuResult<GpuStop> {
    start_media_foundation()?;
    // Always balance the startup above, including on the early failures that
    // send us to the CPU fallback.
    let result = stream_inner(target, config, sink);
    let _ = unsafe { MFShutdown() };
    result
}

fn stream_inner(
    target: CaptureTarget,
    config: &GpuConfig,
    sink: &mut dyn GpuSink,
) -> GpuResult<GpuStop> {
    let item = capture_item(target)?;
    let source = item.Size().map_err(failed("GraphicsCaptureItem::Size"))?;
    let mut source_size = (source.Width.max(1) as u32, source.Height.max(1) as u32);

    let gpu = GpuDevice::new()?;
    let output = target_size(source_size, config.max_height);
    let mut scaler = Scaler::new(&gpu, source_size, output)?;
    let mut encoder = Encoder::new(&gpu, output.0, output.1, config)?;
    log::info!(
        "[capture:gpu] encoder={} output={}x{} fps={} bitrate={} tuned={:?}",
        encoder.name,
        output.0,
        output.1,
        config.fps,
        config.bitrate,
        encoder.tuned,
    );

    let pool = Direct3D11CaptureFramePool::CreateFreeThreaded(
        &gpu.winrt_device,
        DirectXPixelFormat::B8G8R8A8UIntNormalized,
        POOL_BUFFERS,
        source,
    )
    .map_err(failed("CreateFreeThreaded"))?;
    let session = pool
        .CreateCaptureSession(&item)
        .map_err(failed("CreateCaptureSession"))?;
    // The yellow capture border is a Windows 11 affordance; on builds that
    // don't know the property, not having it is the old behaviour anyway.
    if api_present("Windows.Graphics.Capture.GraphicsCaptureSession", "IsBorderRequired") {
        let _ = session.SetIsBorderRequired(false);
    }
    let _ = session.SetIsCursorCaptureEnabled(true);

    // A closed window stops producing frames without any error, which would
    // otherwise look identical to a completely idle screen.
    let closed = Arc::new(AtomicBool::new(false));
    let closed_flag = closed.clone();
    let _token = item.Closed(&TypedEventHandler::new(
        move |_item: windows::core::Ref<'_, GraphicsCaptureItem>, _| {
            closed_flag.store(true, Ordering::Relaxed);
            Ok(())
        },
    ));

    session.StartCapture().map_err(failed("StartCapture"))?;

    let result = run_loop(
        &pool,
        &mut scaler,
        &mut encoder,
        config,
        &mut source_size,
        &gpu,
        sink,
        &closed,
    );

    let _ = session.Close();
    let _ = pool.Close();
    // The encoder has to let go of Media Foundation before its caller shuts
    // it down.
    drop(encoder);
    result
}

fn run_loop(
    pool: &Direct3D11CaptureFramePool,
    scaler: &mut Scaler,
    encoder: &mut Encoder,
    config: &GpuConfig,
    source_size: &mut (u32, u32),
    gpu: &GpuDevice,
    sink: &mut dyn GpuSink,
    closed: &AtomicBool,
) -> GpuResult<GpuStop> {
    // The async transform grants permission to submit one frame per
    // `NeedInput`; submitting without one is a protocol error.
    let mut credits: u32 = 0;
    let mut last_submit: Option<Instant> = None;
    let mut pending_config = true;
    // Stage timings can only be attributed once the frame actually comes out
    // of the encoder. With B-frames disabled, output order matches submission
    // order, so a queue is enough to pair them up.
    let mut in_flight: VecDeque<(f64, Instant)> = VecDeque::new();

    while sink.keep_going() {
        if closed.load(Ordering::Relaxed) {
            return Ok(GpuStop::SourceClosed);
        }
        let mut worked = false;

        // Encoder events first: output already in flight is more valuable
        // than a fresher capture, and draining keeps `credits` accurate.
        while let Some(event) = encoder.poll_event()? {
            worked = true;
            match event {
                EncoderEvent::NeedInput => credits = credits.saturating_add(1),
                EncoderEvent::HaveOutput => {
                    if let Some(encoded) = encoder.take_output()? {
                        let (scale_ms, submitted) =
                            in_flight.pop_front().unwrap_or((0.0, Instant::now()));
                        let config_frame = pending_config
                            .then(|| encoder.parameter_sets.clone())
                            .filter(|sets| !sets.is_empty());
                        pending_config = config_frame.is_none() && pending_config;
                        if !sink.frame(GpuFrame {
                            width: scaler.width,
                            height: scaler.height,
                            config: config_frame,
                            scale_ms,
                            encode_ms: submitted.elapsed().as_secs_f64() * 1000.0,
                            encoded,
                        }) {
                            return Ok(GpuStop::Stopped);
                        }
                    }
                }
            }
        }

        if sink.keyframe_requested() {
            encoder.force_keyframe();
            pending_config = true;
        }

        let due = last_submit.is_none_or(|at| at.elapsed() >= config.frame_interval);
        if credits == 0 || !due || sink.congested() {
            if !worked {
                // Nothing to do: 1 ms keeps us responsive at 60 FPS while
                // costing nothing measurable.
                thread::sleep(Duration::from_millis(1));
            }
            continue;
        }

        // Take the newest frame the pool has and count the rest as stale: a
        // backlog is old screen state, not useful video.
        let mut frame = None;
        let mut skipped = 0u32;
        while let Ok(next) = pool.TryGetNextFrame() {
            if frame.is_some() {
                skipped += 1;
            }
            frame = Some(next);
        }
        if skipped > 0 {
            sink.dropped_stale(skipped);
        }
        let Some(frame) = frame else {
            if !worked {
                sink.starved();
                thread::sleep(Duration::from_millis(1));
            }
            continue;
        };

        let content = frame
            .ContentSize()
            .map_err(failed("Direct3D11CaptureFrame::ContentSize"))?;
        let content = (content.Width.max(1) as u32, content.Height.max(1) as u32);
        if content != *source_size {
            // The source was resized. The pool has to follow it, but the
            // encoder does not: the scaler letterboxes into the fixed output
            // so the stream never changes resolution mid-flight.
            *source_size = content;
            let _ = pool.Recreate(
                &gpu.winrt_device,
                DirectXPixelFormat::B8G8R8A8UIntNormalized,
                POOL_BUFFERS,
                SizeInt32 {
                    Width: content.0 as i32,
                    Height: content.1 as i32,
                },
            );
        }

        let surface = frame.Surface().map_err(failed("Direct3D11CaptureFrame::Surface"))?;
        let texture = unsafe {
            surface
                .cast::<IDirect3DDxgiInterfaceAccess>()
                .map_err(failed("IDirect3DDxgiInterfaceAccess"))?
                .GetInterface::<ID3D11Texture2D>()
                .map_err(failed("GetInterface(ID3D11Texture2D)"))?
        };

        let time = frame
            .SystemRelativeTime()
            .map(|span| span.Duration)
            .unwrap_or_default();

        let scale_started = Instant::now();
        let nv12 = match scaler.convert(&texture, content) {
            Ok(nv12) => nv12,
            Err(error) => return device_lost_or(error),
        };
        let scale_ms = scale_started.elapsed().as_secs_f64() * 1000.0;

        let submitted = Instant::now();
        if let Err(error) = encoder.submit(&nv12, time) {
            return device_lost_or(error);
        }
        credits -= 1;
        last_submit = Some(submitted);
        in_flight.push_back((scale_ms, submitted));
    }

    Ok(GpuStop::Stopped)
}

/// HRESULTs meaning every D3D11 and Media Foundation object we hold has become
/// invalid — a driver reset (TDR), a GPU hang, or an adapter that went away.
/// `failed` renders the code as `(<i32>)`, which is what this matches on.
const DEVICE_LOST_CODES: [i32; 4] = [
    -2005270523, // DXGI_ERROR_DEVICE_REMOVED
    -2005270522, // DXGI_ERROR_DEVICE_HUNG
    -2005270521, // DXGI_ERROR_DEVICE_RESET
    -2005270496, // DXGI_ERROR_DRIVER_INTERNAL_ERROR
];

/// Nothing is recoverable in place after a device loss, so report it and let
/// the caller restart the session or fall back to the CPU path.
fn device_lost_or(error: GpuError) -> GpuResult<GpuStop> {
    let reason = error.reason();
    if DEVICE_LOST_CODES
        .iter()
        .any(|code| reason.contains(&format!("({code})")))
    {
        return Ok(GpuStop::DeviceLost);
    }
    Err(error)
}

/// What to capture, resolved from the picker's source id by the caller.
pub enum CaptureTarget {
    Screen(u32),
    Window(u32),
}

fn capture_item(target: CaptureTarget) -> GpuResult<GraphicsCaptureItem> {
    let interop = windows::core::factory::<GraphicsCaptureItem, IGraphicsCaptureItemInterop>()
        .map_err(unsupported("IGraphicsCaptureItemInterop"))?;
    match target {
        CaptureTarget::Screen(id) => {
            let monitor = monitor_handle(id)?;
            unsafe { interop.CreateForMonitor(monitor) }.map_err(failed("CreateForMonitor"))
        }
        CaptureTarget::Window(id) => {
            let window = window_handle(id)?;
            unsafe { interop.CreateForWindow(window) }.map_err(failed("CreateForWindow"))
        }
    }
}

/// Windows.Graphics.Capture has grown properties over time and touching one
/// the running build doesn't have throws, so ask first — the same approach
/// the WASAPI path takes with its build-number gate.
fn api_present(type_name: &str, member: &str) -> bool {
    ApiInformation::IsPropertyPresent(&HSTRING::from(type_name), &HSTRING::from(member))
        .unwrap_or(false)
}

fn activate_name(activate: &IMFActivate) -> String {
    let mut pointer = windows::core::PWSTR::null();
    let mut length = 0u32;
    if unsafe { activate.GetAllocatedString(&MFT_FRIENDLY_NAME_Attribute, &mut pointer, &mut length) }
        .is_err()
    {
        return "unknown".to_string();
    }
    let name = unsafe { pointer.to_string() }.unwrap_or_else(|_| "unknown".to_string());
    unsafe { CoTaskMemFree(Some(pointer.as_ptr() as *const c_void)) };
    name
}

// The picker's source ids come from xcap, which derives them by truncating the
// handle to 32 bits (`hwnd.0 as u32` / `h_monitor.0 as u32`). The handle itself
// is unrecoverable from that, so the only way back is to enumerate again and
// truncate the same way.

unsafe extern "system" fn collect_monitor(
    monitor: HMONITOR,
    _hdc: HDC,
    _rect: *mut RECT,
    data: LPARAM,
) -> windows::core::BOOL {
    let found = unsafe { &mut *(data.0 as *mut Vec<HMONITOR>) };
    found.push(monitor);
    true.into()
}

pub fn monitor_handle(id: u32) -> GpuResult<HMONITOR> {
    let mut monitors: Vec<HMONITOR> = Vec::new();
    unsafe {
        let _ = EnumDisplayMonitors(
            None,
            None,
            Some(collect_monitor),
            LPARAM(&mut monitors as *mut Vec<HMONITOR> as isize),
        );
    }
    monitors
        .into_iter()
        .find(|monitor| monitor.0 as u32 == id)
        .ok_or_else(|| GpuError::Failed("That screen is no longer available".into()))
}

unsafe extern "system" fn collect_window(window: HWND, data: LPARAM) -> windows::core::BOOL {
    if unsafe { IsWindowVisible(window) }.as_bool() {
        let found = unsafe { &mut *(data.0 as *mut Vec<HWND>) };
        found.push(window);
    }
    true.into()
}

pub fn window_handle(id: u32) -> GpuResult<HWND> {
    let mut windows: Vec<HWND> = Vec::new();
    unsafe {
        let _ = EnumWindows(
            Some(collect_window),
            LPARAM(&mut windows as *mut Vec<HWND> as isize),
        );
    }
    windows
        .into_iter()
        .find(|window| window.0 as u32 == id)
        .ok_or_else(|| GpuError::Failed("That window has been closed".into()))
}

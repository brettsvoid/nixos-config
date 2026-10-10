//! Captures the default output's monitor through PipeWire, on a thread of its own, and
//! hands bar heights to a callback. Dropping a `Capture` ends the stream, so nothing is
//! captured while the bars are not wanted.
//!
//! Nothing here may unwind into Qt: a panic ends the run like a lost connection does,
//! the bars go flat, and while still wanted it tries again a second later.

use crate::analysis::Analyser;
use pipewire as pw;
use pw::{properties::properties, spa};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

pub type Publish = Arc<dyn Fn(Vec<f64>) + Send + Sync>;

pub struct Capture {
    stop: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<()>>,
}

impl Capture {
    pub fn start(count: usize, publish: Publish) -> Capture {
        let stop = Arc::new(AtomicBool::new(false));
        let thread = {
            let stop = stop.clone();
            std::thread::Builder::new()
                .name("spectrum".into())
                .spawn(move || {
                    while !stop.load(Ordering::Relaxed) {
                        let run = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                            run(count, &stop, &publish)
                        }));
                        match run {
                            Ok(Ok(())) => {}
                            Ok(Err(error)) => eprintln!("spectrum: {error}"),
                            Err(_) => eprintln!("spectrum: the capture thread panicked"),
                        }
                        publish(vec![0.0; count]);
                        for _ in 0..10 {
                            if stop.load(Ordering::Relaxed) {
                                return;
                            }
                            std::thread::sleep(Duration::from_millis(100));
                        }
                    }
                })
                .ok()
        };
        Capture { stop, thread }
    }
}

impl Drop for Capture {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

struct State {
    analyser: Analyser,
    channels: usize,
    last_audio: Instant,
}

/// One connection: returns when asked to stop, or when PipeWire goes away.
fn run(
    count: usize,
    stop: &Arc<AtomicBool>,
    publish: &Publish,
) -> Result<(), Box<dyn std::error::Error>> {
    pw::init();
    let mainloop = pw::main_loop::MainLoopRc::new(None)?;
    let context = pw::context::ContextRc::new(&mainloop, None)?;
    let core = context.connect_rc(None)?;

    let _core_listener = core
        .add_listener_local()
        .error({
            let mainloop = mainloop.clone();
            move |id, _seq, _res, message| {
                if id == pw::core::PW_ID_CORE {
                    eprintln!("spectrum: PipeWire: {message}");
                    mainloop.quit();
                }
            }
        })
        .register();

    let props = properties! {
        *pw::keys::MEDIA_TYPE => "Audio",
        *pw::keys::MEDIA_CATEGORY => "Capture",
        *pw::keys::MEDIA_ROLE => "Music",
        // The monitor of the default output, following it when the default changes.
        *pw::keys::STREAM_CAPTURE_SINK => "true",
        // Do not keep an idle output awake.
        *pw::keys::NODE_PASSIVE => "true",
        *pw::keys::NODE_NAME => "custom-shell-spectrum",
        *pw::keys::APP_NAME => "Custom shell",
    };
    let stream = pw::stream::StreamBox::new(&core, "custom-shell-spectrum", props)?;

    let state = Rc::new(RefCell::new(State {
        analyser: Analyser::new(count, 48_000),
        channels: 2,
        last_audio: Instant::now(),
    }));

    let _listener = stream
        .add_local_listener_with_user_data(())
        .param_changed({
            let state = state.clone();
            move |_, _, id, param| {
                let Some(param) = param else { return };
                if id != spa::param::ParamType::Format.as_raw() {
                    return;
                }
                let mut info = spa::param::audio::AudioInfoRaw::new();
                if info.parse(param).is_ok() {
                    let mut state = state.borrow_mut();
                    state.channels = info.channels().max(1) as usize;
                    state.analyser = Analyser::new(count, info.rate());
                }
            }
        })
        .state_changed({
            let mainloop = mainloop.clone();
            move |_, _, _, new| {
                if let pw::stream::StreamState::Error(message) = new {
                    eprintln!("spectrum: stream: {message}");
                    mainloop.quit();
                }
            }
        })
        .process({
            let state = state.clone();
            let publish = publish.clone();
            move |stream, _| {
                let Some(mut buffer) = stream.dequeue_buffer() else {
                    return;
                };
                let Some(data) = buffer.datas_mut().first_mut() else {
                    return;
                };
                let size = data.chunk().size() as usize;
                let Some(bytes) = data.data() else { return };
                let samples: Vec<f32> = bytes[..size.min(bytes.len())]
                    .as_chunks::<4>()
                    .0
                    .iter()
                    .map(|b| f32::from_le_bytes(*b))
                    .collect();
                let mut state = state.borrow_mut();
                state.last_audio = Instant::now();
                let channels = state.channels;
                if state.analyser.push(&samples, channels) {
                    publish(state.analyser.bars().to_vec());
                }
            }
        })
        .register()?;

    // 32-bit float at whatever rate and channels the graph runs.
    let mut format = spa::param::audio::AudioInfoRaw::new();
    format.set_format(spa::param::audio::AudioFormat::F32LE);
    let object = spa::pod::Object {
        type_: spa::utils::SpaTypes::ObjectParamFormat.as_raw(),
        id: spa::param::ParamType::EnumFormat.as_raw(),
        properties: format.into(),
    };
    let bytes = spa::pod::serialize::PodSerializer::serialize(
        std::io::Cursor::new(Vec::new()),
        &spa::pod::Value::Object(object),
    )?
    .0
    .into_inner();
    let pod = spa::pod::Pod::from_bytes(&bytes).ok_or("could not build the format")?;
    // No RT_PROCESS: the FFT runs on this thread, not PipeWire's realtime one.
    stream.connect(
        spa::utils::Direction::Input,
        None,
        pw::stream::StreamFlags::AUTOCONNECT | pw::stream::StreamFlags::MAP_BUFFERS,
        &mut [pod],
    )?;

    // Ten times a second: stop when asked, and let the bars fall while no audio comes
    // (an idle output sends nothing).
    let timer = mainloop.loop_().add_timer({
        let mainloop = mainloop.clone();
        let stop = stop.clone();
        let publish = publish.clone();
        move |_| {
            if stop.load(Ordering::Relaxed) {
                mainloop.quit();
                return;
            }
            let mut state = state.borrow_mut();
            if state.last_audio.elapsed() > Duration::from_millis(200)
                && state.analyser.bars().iter().any(|&b| b > 0.0)
            {
                state.analyser.decay();
                publish(state.analyser.bars().to_vec());
            }
        }
    });
    timer.update_timer(
        Some(Duration::from_millis(100)),
        Some(Duration::from_millis(100)),
    );

    mainloop.run();
    Ok(())
}

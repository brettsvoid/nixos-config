//! `Spectrum`, the QML side: set `active` while the bars are shown and something plays,
//! and read `bars`, `count` heights from 0 to 1, lowest frequency first. Capture runs
//! only while `active` is true and stops when it turns false or the object goes.

use crate::capture::Capture;
use core::pin::Pin;
use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QList;
use std::sync::Arc;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qlist.h");
        type QList_f64 = cxx_qt_lib::QList<f64>;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(bool, active)]
        #[qproperty(i32, count)]
        #[qproperty(QList_f64, bars)]
        type Spectrum = super::SpectrumRust;
    }

    impl cxx_qt::Threading for Spectrum {}
    impl cxx_qt::Initialize for Spectrum {}
}

pub struct SpectrumRust {
    active: bool,
    count: i32,
    bars: QList<f64>,
    capture: Option<Capture>,
}

impl Default for SpectrumRust {
    fn default() -> Self {
        SpectrumRust {
            active: false,
            count: 32,
            bars: flat(32),
            capture: None,
        }
    }
}

fn flat(count: i32) -> QList<f64> {
    let mut list = QList::default();
    for _ in 0..count.max(0) {
        list.append(0.0);
    }
    list
}

impl cxx_qt::Initialize for qobject::Spectrum {
    fn initialize(mut self: Pin<&mut Self>) {
        self.as_mut()
            .on_active_changed(|spectrum| spectrum.restart())
            .release();
        self.as_mut()
            .on_count_changed(|spectrum| spectrum.restart())
            .release();
    }
}

impl qobject::Spectrum {
    /// Stops any capture, then starts one if the bars are wanted.
    fn restart(mut self: Pin<&mut Self>) {
        // Dropping the capture stops its thread and waits for it.
        self.as_mut().rust_mut().capture = None;
        let count = *self.count();
        self.as_mut().set_bars(flat(count));
        if !*self.active() || count <= 0 {
            return;
        }
        let qt_thread = self.qt_thread();
        let publish = Arc::new(move |heights: Vec<f64>| {
            // Fails only once the object is gone, when nobody needs the values.
            let _ = qt_thread.queue(move |spectrum| {
                let mut list = QList::default();
                for height in heights {
                    list.append(height);
                }
                spectrum.set_bars(list);
            });
        });
        self.as_mut().rust_mut().capture = Some(Capture::start(count as usize, publish));
    }
}

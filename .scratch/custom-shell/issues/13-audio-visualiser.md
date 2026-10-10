# Audio visualiser as a Rust plugin in the dashboard's media card

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Spectrum bars behind or below the dashboard's media card that move with whatever is
playing. Audio arrives at frame rate, so this is the one place for an in-process Rust
QML plugin built with cxx-qt rather than a separate program.

- Capture the default output's monitor stream from PipeWire, run an FFT, and expose a
  list of bar heights to QML (Quickshell only offers peak levels, not a spectrum).
- Capture only while the bars are visible and something is playing. Stop the stream
  otherwise.
- Draw the bars on the GPU (a QML shape or shader), not a CPU-painted item.
- A crash in the plugin takes the whole shell down, so the audio side must fail safely
  (no panics across the FFI boundary; a lost stream just shows flat bars).

A prototype on 2026-10-09 showed that a cxx-qt 0.10 dynamic QML plugin loads in this
flake's `qs` (Qt 6.11.2, the same Qt derivations as `pkgs.qt6`). It only loaded after
keeping Qt's plugin entry points exported from the cdylib. Decision-rich parts of the
prototype's `build.rs` (technique from nova-shell's `plugin/build.rs`):

```rust
// Keep Qt's plugin entry points alive and exported from the cdylib.
for sym in ["qt_plugin_instance", "qt_plugin_query_metadata_v2"] {
    println!("cargo::rustc-cdylib-link-arg=-Wl,--undefined={sym}");
}
// plus -Wl,--version-script=<map> listing both symbols under `global:`
CxxQtBuilder::new_qml_module(QmlModule::new("My.Module").plugin_type(PluginType::Dynamic))
```

Other prototype findings: cxx-qt finds Qt through `qmake -query`, which in nixpkgs needs
a `qt6.env` with qtdeclarative and `QMAKE` set again after qtbase's setup hook; the
plugin reaches `qs` through the Quickshell package's `withModules`.

## Acceptance criteria

- [ ] With music playing and the dashboard open, the bars move in time with the audio.
- [ ] With the dashboard closed or playback paused, no audio stream is open (check with
      `pw-top` or `pw-cli`).
- [ ] Killing PipeWire or switching the output device does not crash the shell.
- [ ] The plugin builds from the flake against the same Qt as Quickshell.
- [ ] CPU use with the bars showing stays low (measure and note the figure here).

## Blocked by

- .scratch/custom-shell/issues/11-dashboard-drawer.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop. Test audio went into a temporary null
sink set as the default output (except once, below), and the audio setup was checked
afterwards each time.
- `modules/home/desktop/shell-native`: Rust, cxx-qt 0.10, a dynamic QML plugin
  `CustomShell.Native` with one type, `Spectrum` (`active`, `count` in; `bars`, a
  `QList<f64>` of 0..1 heights, out). While active, a thread runs a PipeWire main loop
  with a capture stream on the default output's monitor (`stream.capture.sink`, so it
  follows the default; `node.passive`, so it never keeps an idle output awake), FFTs
  (rustfft) 2048 Hann-windowed samples every 1024, folds them into log-spaced bands,
  and queues the heights to the Qt thread. A 100 ms timer checks the stop flag and lets
  the bars fall when no audio arrives. Each run is inside `catch_unwind`; a lost
  connection or panic flattens the bars, and it retries every second while active.
  Inactive or destroyed, the thread is stopped and joined.
- Build: `buildRustPackage` in custom-shell.nix (qmake from `qt6.env` with
  qtdeclarative, lld, bindgen for pipewire-rs), installed as
  `lib/qt-6/qml/CustomShell/Native`, with a run path patched in to the same
  qtbase/qtdeclarative Quickshell uses; `qsPkg` is now Quickshell `.withModules`. The
  unit tests (a 1 kHz tone lights its own band above 0.9; silence stays flat; decay
  reaches zero) run in the build. Two traps beyond the prototype's: an unused
  `cxx_qt_lib` is not linked (undefined `cxx_qt_init_crate_cxx_qt_lib`; using its QList
  fixes it), and the test binary needs LD_LIBRARY_PATH in the sandbox.
- QML: `dashboard/Visualiser.qml`, 32 rounded bars behind the media card's controls
  (scene-graph rectangles, redrawn only per update). MediaCard loads it through a
  Loader, active while the player plays, so a qs without the plugin just omits it.
- Checked: the capture stream exists only with the dashboard open and the player
  playing (gone on pause and on closing); a 440 Hz tone lit the matching bars; switching
  the default output (headset → null sink → headset) moved the capture with it;
  `systemctl --user restart pipewire` left both the shell and a test shell running, the
  plugin logged "PipeWire: connection error" and reconnected, and the shell's own audio
  (bar, OSD) kept working.
- CPU, per thread over 10 s: with the bars moving about 3–4% of one core more than with
  the dashboard closed (spectrum 0.4%, the rest the shell redrawing them ~47 times a
  second).
- Found on the way: MangoHud (enabled session-wide, profile-gaming) loads into the
  shell's Vulkan renderer, and its `mangohud-nvidia` thread used about 28% of a core
  all the time, visualiser or not. `toggle-shell custom` and `qs-dev` now set
  `DISABLE_MANGOHUD=1` (the layer's own off switch): idle went to about 2%. Caelestia's
  Quickshell likely pays the same cost (not measured).
- Mishap during testing: one run picked the wrong PipeWire node (a sloppy grep),
  so a 4 s 1 kHz test tone played through the headset, and its cleanup destroyed the
  ALSA MIDI bridge node; restarting WirePlumber recreated it. Node lookups now go by
  name through pw-dump.

# Audio visualiser as a Rust plugin in the dashboard's media card

Status: ready-for-agent
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

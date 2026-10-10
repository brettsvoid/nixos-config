use cxx_qt_build::{CxxQtBuilder, PluginType, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("CustomShell.Native").plugin_type(PluginType::Dynamic),
    )
    .file("src/spectrum.rs")
    .build();

    // Qt loads a QML plugin through these two C++ entry points. Rust links a cdylib
    // exporting only Rust's own symbols and drops the rest, so keep them and export
    // them (the technique from nova-shell's plugin/build.rs).
    let entry_points = ["qt_plugin_instance", "qt_plugin_query_metadata_v2"];
    for symbol in entry_points {
        println!("cargo::rustc-cdylib-link-arg=-Wl,--undefined={symbol}");
    }
    let map = std::path::Path::new(&std::env::var("OUT_DIR").expect("OUT_DIR is set by cargo"))
        .join("qt-plugin.map");
    std::fs::write(
        &map,
        format!("{{ global: {}; }};\n", entry_points.join("; ")),
    )
    .expect("write the version script");
    println!(
        "cargo::rustc-cdylib-link-arg=-Wl,--version-script={}",
        map.display()
    );
}

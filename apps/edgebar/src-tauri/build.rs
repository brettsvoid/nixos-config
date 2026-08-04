fn main() {
    // Brightness control uses Apple's private DisplayServices framework
    // (DisplayServicesGet/SetBrightness) — the same internal-display path the
    // `brightness` CLI uses. It lives in PrivateFrameworks, so add that search
    // path and link it explicitly. Private API: may change across macOS versions.
    #[cfg(target_os = "macos")]
    {
        println!(
            "cargo:rustc-link-search=framework=/System/Library/PrivateFrameworks"
        );
        println!("cargo:rustc-link-lib=framework=DisplayServices");
        // The notch's media readout asks CoreAudio which processes are writing
        // to an output device (public API since 14.4 — see notch.rs for why
        // that, and not MediaRemote, is the source).
        println!("cargo:rustc-link-lib=framework=CoreAudio");
    }

    tauri_build::build()
}

fn main() {
    // Brightness uses the private DisplayServices framework
    // (DisplayServicesGet/SetBrightness), which lives in PrivateFrameworks.
    // Private API: may change across macOS versions.
    #[cfg(target_os = "macos")]
    {
        println!(
            "cargo:rustc-link-search=framework=/System/Library/PrivateFrameworks"
        );
        println!("cargo:rustc-link-lib=framework=DisplayServices");
        // The notch's media readout asks CoreAudio which processes are playing
        // (see notch.rs for why not MediaRemote).
        println!("cargo:rustc-link-lib=framework=CoreAudio");
    }

    tauri_build::build()
}

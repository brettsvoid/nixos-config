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
    }

    tauri_build::build()
}

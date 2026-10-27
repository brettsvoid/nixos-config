# edgebar.app, built the way `pnpm tauri build` builds it: cargo-tauri.hook
# runs `cargo tauri build`, whose beforeBuildCommand (`pnpm build`) bundles
# the WebView first. The result is ad-hoc signed; modules/home/darwin/edgebar.nix
# re-signs a copy so macOS permissions survive rebuilds.
{
  lib,
  rustPlatform,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  cargo-tauri,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "edgebar";
  inherit ((lib.importTOML ./src-tauri/Cargo.toml).package) version;

  # Only what the build reads, so README or scripts/ edits don't rebuild it.
  # maybeMissing: target/ exists only in a working tree, never in the flake's
  # git-tracked copy.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./index.html
      ./package.json
      ./pnpm-lock.yaml
      ./tsconfig.json
      ./vite.config.ts
      ./src
      (lib.fileset.difference ./src-tauri (lib.fileset.maybeMissing ./src-tauri/target))
    ];
  };

  # Update the hash whenever pnpm-lock.yaml changes: set it to lib.fakeHash,
  # build, and copy the hash from the mismatch error.
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-g5upRuAc0YnluF+CYqHI2nN45j8JKC2Um48+50qm3C8=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoLock.lockFile = ./src-tauri/Cargo.lock;

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs
    cargo-tauri.hook
  ];

  # The tests run in development (`cargo test`); here they would only double
  # every rebuild with a second, debug compile.
  doCheck = false;

  meta = {
    description = "Top status bar for macOS, after the brett-desktop custom shell";
    platforms = lib.platforms.darwin;
  };
})

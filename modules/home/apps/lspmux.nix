# lspmux — share one rust-analyzer between every LSP client on the machine.
# https://codeberg.org/p2502/lspmux (formerly ra-multiplex)
#
# ─── The problem ───────────────────────────────────────────────────────
# Claude Code's rust-analyzer-lsp plugin starts a server per session, not per
# workspace: ~4 GB each on the tyto tree. Idle between prompts, they get
# swapped out and paged back in on every return to a session. rust-analyzer
# serves one client over stdio, so lspmux proxies many clients onto one server
# per workspace root and server command, and reaps instances that go idle.
#
# ─── Why a PATH shim is the hook ───────────────────────────────────────
# The plugin's manifest declares a bare command (`"command": "rust-analyzer"`),
# so Claude Code resolves it from PATH and a shim earlier on PATH captures
# every session with no Claude-side config. nvim shares it too: rustaceanvim
# sets no `server.cmd` (nvim/config/lua/plugins/rust.lua).
_: {
  flake.modules.homeManager.apps-lspmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      lspmuxBin = "${pkgs.lspmux}/bin/lspmux";
      shimDir = "${config.home.homeDirectory}/.local/share/lspmux-shim";

      # Named `rust-analyzer` because that is the name every client looks up;
      # it decides per launch whether to multiplex.
      raShim = pkgs.writeShellApplication {
        name = "rust-analyzer";
        # No runtimeInputs on purpose: the real server must be found through
        # rustup (a Homebrew install on both Macs), not the nix profile, or
        # per-project toolchain pins stop being honoured.
        text = ''
          # Resolve the real server for this project's toolchain. rustup reads
          # rust-toolchain.toml relative to the cwd, which both Claude Code
          # and nvim set to the workspace root. Must stay dynamic: projects
          # can pin a toolchain other than the default.
          real=""
          if command -v rustup >/dev/null 2>&1; then
            real="$(rustup which rust-analyzer 2>/dev/null || true)"
          fi

          # Absolute fallbacks only: a bare `rust-analyzer` would resolve back
          # to this shim (first on PATH) and loop.
          if [ -z "$real" ] || [ ! -x "$real" ]; then
            for candidate in \
              /opt/homebrew/opt/rustup/bin/rust-analyzer \
              "$HOME/.cargo/bin/rust-analyzer"; do
              if [ -x "$candidate" ]; then
                real="$candidate"
                break
              fi
            done
          fi

          if [ -z "$real" ] || [ ! -x "$real" ]; then
            echo "rust-analyzer shim: no rust-analyzer found (rustup which failed, no fallback on disk)" >&2
            exit 127
          fi

          # Multiplex when the daemon is up. Without it `lspmux client` exits
          # at once and the LSP client sees a closed pipe, so probe first and
          # fall back to a private server.
          if ${lspmuxBin} status >/dev/null 2>&1; then
            exec ${lspmuxBin} client --server-path "$real" "$@"
          fi

          exec "$real" "$@"
        '';
      };
    in
    lib.mkIf pkgs.stdenv.isDarwin {
      home.packages = [ pkgs.lspmux ];

      home.file."${lib.removePrefix "${config.home.homeDirectory}/" shimDir}/rust-analyzer".source =
        "${raShim}/bin/rust-analyzer";

      # Must land ahead of Homebrew's rustup proxies, or they win and the shim
      # never runs (so ~/.local/bin, which is behind them, won't do).
      # shell/env.nix prepends `$(brew --prefix rustup)/bin` in its mkOrder
      # 600 block; mkOrder 700 runs later, so this prepend lands further
      # forward. env.nix's `_prepend` isn't used, to avoid depending on
      # another module's shell function.
      programs.zsh.initContent = lib.mkOrder 700 ''
        # rust-analyzer multiplexer shim (apps-lspmux) — ahead of rustup's proxy
        case ":$PATH:" in
          *":${shimDir}:"*) ;;
          *) PATH="${shimDir}:$PATH" ;;
        esac
        export PATH
      '';

      # The daemon. KeepAlive because a dead daemon, though survivable (the
      # shim falls back), puts every client back on its own server.
      #
      # EnvironmentVariables.PATH is load-bearing: lspmux spawns rust-analyzer
      # with the daemon's environment (`pass_environment` defaults to empty),
      # and launchd gives agents only /usr/bin:/bin:/usr/sbin:/sbin, where
      # rust-analyzer starts but reports "Failed to load workspaces." as it
      # cannot exec cargo. The rustup proxy directory, not a resolved
      # toolchain, keeps each project's rust-toolchain.toml honoured.
      launchd.agents.lspmux = {
        enable = true;
        config = {
          ProgramArguments = [
            lspmuxBin
            "server"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Background";
          EnvironmentVariables = {
            PATH = lib.concatStringsSep ":" [
              "/opt/homebrew/opt/rustup/bin"
              "${config.home.homeDirectory}/.cargo/bin"
              "/run/current-system/sw/bin"
              "${config.home.homeDirectory}/.nix-profile/bin"
              "/opt/homebrew/bin"
              "/usr/bin"
              "/bin"
              "/usr/sbin"
              "/sbin"
            ];
          };
          StandardOutPath = "/tmp/lspmux.log";
          StandardErrorPath = "/tmp/lspmux.log";
        };
      };

      # instance_timeout reaps an index no client has touched for 5 minutes,
      # rather than leaving it resident to be swapped. Both values equal
      # lspmux 0.3.0's built-in defaults.
      home.file."Library/Application Support/lspmux/config.toml".text = ''
        instance_timeout = 300
        gc_interval = 10
      '';
    };
}

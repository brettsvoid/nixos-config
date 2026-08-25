# lspmux — share ONE rust-analyzer between every LSP client on the machine.
# https://codeberg.org/p2502/lspmux (the project formerly called ra-multiplex)
#
# ─── The problem, measured on brett-mac-mini (24 GB) ───────────────────
# Claude Code's rust-analyzer-lsp plugin starts a server PER SESSION, not per
# workspace. Three concurrent sessions on the tyto tree held 3.9 + 3.8 + 3.7 GB
# of physical footprint — two of them indexing the IDENTICAL /projects/tyto
# root. Because they idle between prompts, macOS had compressed and swapped
# essentially all of it (`vmmap` showed ~100% swapped_out), so every return to
# a session paged ~4 GB back in. That churn, not the Docker VM, was the main
# source of swap traffic once Docker was capped.
#
# rust-analyzer cannot be shared by itself: it speaks LSP over stdio to exactly
# one client and has no daemon or multi-client mode. lspmux is a proxy that
# keeps one server per (workspace root, server args) and fans many clients onto
# it, reaping instances that go idle.
#
# ─── Why a PATH shim is the hook ───────────────────────────────────────
# The plugin's marketplace manifest declares a BARE command name:
#
#   "lspServers": { "rust-analyzer": { "command": "rust-analyzer", ... } }
#
# so Claude Code resolves it from PATH at launch. A shim earlier on PATH
# therefore captures every session with no Claude-side configuration at all.
# nvim comes along for free: rustaceanvim does not set `server.cmd`
# (nvim/config/lua/plugins/rust.lua), so it resolves rust-analyzer from PATH too
# and ends up on the same shared instance.
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

      # The shim. Named `rust-analyzer` because that is the name every client
      # looks up; it decides per-launch whether to multiplex.
      raShim = pkgs.writeShellApplication {
        name = "rust-analyzer";
        # No runtimeInputs on purpose. rustup is a Homebrew install on both
        # Macs and the real server has to be found THROUGH it, not through the
        # nix profile, or per-project toolchain pins stop being honoured.
        text = ''
          # Resolve the real server for THIS project's toolchain. rustup reads
          # rust-toolchain.toml relative to the cwd, and both Claude Code and
          # nvim launch the server with cwd = workspace root. That resolution
          # must stay dynamic: /projects/tyto pins 1.90.0 while the default
          # toolchain is stable, so a hardcoded path would serve the wrong
          # rust-analyzer to one of them.
          real=""
          if command -v rustup >/dev/null 2>&1; then
            real="$(rustup which rust-analyzer 2>/dev/null || true)"
          fi

          # Absolute fallbacks ONLY. A bare `rust-analyzer` here would resolve
          # straight back to this shim — the shim is first on PATH — and fork a
          # loop. Both candidates below are rustup proxies or real binaries.
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

          # Multiplex when the daemon is up. When it is NOT, `lspmux client`
          # exits immediately and the LSP client just sees a server that closed
          # the pipe — verified by killing the daemon mid-test. So probe first
          # and fall through to a private instance, which degrades to today's
          # one-server-per-session behaviour instead of breaking every Rust
          # client on the machine.
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

      # PATH. This MUST land ahead of Homebrew's rustup proxies: shell/env.nix
      # prepends `$(brew --prefix rustup)/bin` inside its mkOrder 600 block,
      # which measured at PATH position 58 against 63 for ~/.local/bin — a shim
      # dropped in ~/.local/bin would silently lose to the proxy and the whole
      # mechanism would no-op. mkOrder 700 runs after that block, so this
      # prepend lands further forward and wins.
      #
      # Deliberately NOT reusing env.nix's `_prepend` helper: that would make
      # this module depend on a shell function defined by another one.
      programs.zsh.initContent = lib.mkOrder 700 ''
        # rust-analyzer multiplexer shim (apps-lspmux) — ahead of rustup's proxy
        case ":$PATH:" in
          *":${shimDir}:"*) ;;
          *) PATH="${shimDir}:$PATH" ;;
        esac
        export PATH
      '';

      # The daemon. KeepAlive because the shim's fallback means a dead daemon is
      # survivable but wasteful — every client would go back to its own server.
      #
      # EnvironmentVariables.PATH is LOAD-BEARING, not boilerplate. lspmux
      # spawns rust-analyzer from the DAEMON's environment (its Connect request
      # carries cwd, and `pass_environment` defaults to empty), and launchd
      # gives an agent a bare /usr/bin:/bin:/usr/sbin:/sbin. Verified: with that
      # minimal PATH rust-analyzer initializes fine and then reports
      # "Failed to load workspaces." because it cannot exec cargo. With the
      # rustup proxies on PATH the error disappears.
      #
      # The rustup PROXY directory is listed rather than a resolved toolchain
      # bin, so cargo still honours each project's rust-toolchain.toml.
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

      # instance_timeout is the point of the exercise: an index that no client
      # has touched for 5 minutes is reaped outright rather than left resident
      # to be compressed and swapped. That is the soft cap the Docker VM's
      # balloon could not give us — see docker-vm-memory-hard-cap in memory.
      home.file."Library/Application Support/lspmux/config.toml".text = ''
        instance_timeout = 300
        gc_interval = 10
      '';
    };
}

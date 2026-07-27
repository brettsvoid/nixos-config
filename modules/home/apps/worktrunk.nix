# worktrunk (`wt`) — git worktree manager aimed at running coding agents in
# parallel. https://worktrunk.dev
#
# This module owns EVERYTHING about the tool: the package, the shell
# integration and the `wsc` alias. That is deliberate — putting the alias in
# shell/aliases.nix instead would ship it to hosts that never import this
# module, which is exactly the bug the repo's own refactor-plan records as
# finding N-1 (`nix-rebuild` reaching a host with no nh installed).
_: {
  flake.modules.homeManager.apps-worktrunk =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # nixpkgs lists aarch64-darwin in meta.platforms, but the package does
      # not actually build here: two of its 1373 tests read the macOS process
      # table (shell::utils::test_process_name_and_ppid_self and
      # test_probe_reports_invoked_name_for_sh), which the nix build sandbox
      # denies, so checkPhase fails. Nothing is wrong with the code — the
      # process table is readable at runtime, just not to a sandboxed build
      # user — and nixpkgs' Hydra does not build darwin, so the platform claim
      # went untested.
      #
      # Skipping the whole suite rather than the two offending tests: we are
      # consuming this package, not maintaining it. A `--skip=<test-name>` pair
      # would break confusingly the moment upstream renames a test, and there
      # is no action we would take on a failure here other than this. Also
      # cheaper — Rust builds a separate test binary we would only discard.
      worktrunk = pkgs.worktrunk.overrideAttrs (_: {
        doCheck = false;
      });

      # `wt` has to be a shell FUNCTION, not just a binary. The CLI writes the
      # directory to cd into — and any code to eval — into the temp files named
      # by WORKTRUNK_DIRECTIVE_CD_FILE / _EXEC_FILE, and the wrapper applies
      # them to the calling shell after the process exits. A bare binary cannot
      # change its parent's directory, so without this `wt switch` would do
      # nothing visible.
      #
      # Generated at BUILD time into the store rather than by running
      # `wt config shell init zsh` from .zshrc, so interactive shells source a
      # static file instead of spawning a subprocess on every start. Verified
      # the generator needs no repo, no config and no environment, and is
      # byte-identical across runs. HOME is pointed at $TMPDIR because the
      # build sandbox has no home directory.
      shellInit = pkgs.runCommand "worktrunk-shell-init.zsh" { } ''
        export HOME="$TMPDIR"
        ${lib.getExe worktrunk} config shell init zsh > $out
      '';
    in
    {
      home.packages = [ worktrunk ];

      # `wt switch --create <branch>`, launching claude in the new worktree.
      programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
        wsc = "wt switch --create -x claude";
      };

      programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
        lib.mkAfter ''
          # Pin the function to the exact binary its wrapper was generated
          # from. NOT transitional — do not delete this once the Homebrew copy
          # of wt is gone.
          #
          # The wrapper and the binary implement two halves of one protocol:
          # the binary writes the directory to cd into (and any code to eval)
          # to the paths in WORKTRUNK_DIRECTIVE_CD_FILE / _EXEC_FILE, and the
          # wrapper applies them afterwards. Pair a wrapper with a binary of a
          # different version and that contract can drift, which surfaces as
          # confusing partial failures rather than a clean error. The generated
          # wrapper calls `command "''${WORKTRUNK_BIN:-wt}"`, so setting this
          # makes the pairing independent of PATH order — which is not
          # guaranteed: a `cargo install worktrunk` into ~/.cargo/bin would
          # otherwise shadow the nix build.
          #
          # Known cost: this overrides PATH silently. If you deliberately
          # install another `wt` and wonder why it is not being used, this is
          # why — override it per-command with `WORKTRUNK_BIN=... wt ...`, or
          # use the wrapper's own `--source` flag, which runs `cargo run`
          # and ignores this entirely.
          export WORKTRUNK_BIN=${lib.getExe worktrunk}
          source ${shellInit}
        ''
      );
    };
}

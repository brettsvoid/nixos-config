# worktrunk (`wt`) — git worktree manager aimed at running coding agents in
# parallel. https://worktrunk.dev
#
# This module owns the package, the shell integration and the `wsc` alias, so
# the alias never reaches a host without `wt` (the bug docs/refactor-plan.md
# records as N-1, for `nix-rebuild` and nh).
_: {
  flake.modules.homeManager.apps-worktrunk =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # nixpkgs lists aarch64-darwin, but two tests
      # (shell::utils::test_process_name_and_ppid_self and
      # test_probe_reports_invoked_name_for_sh) read the macOS process table,
      # which the build sandbox denies, so checkPhase fails there. The whole
      # suite is skipped because a `--skip` pair would break confusingly once
      # upstream renames a test.
      worktrunk = pkgs.worktrunk.overrideAttrs (_: {
        doCheck = false;
      });

      # `wt` has to be a shell function: the binary writes the directory to
      # cd into (and any code to eval) to the files named by
      # WORKTRUNK_DIRECTIVE_CD_FILE / _EXEC_FILE, and the wrapper applies them
      # to the calling shell afterwards. Generated at build time so shell
      # start-up sources a static file instead of running
      # `wt config shell init zsh`; HOME=$TMPDIR as the sandbox has none.
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
          # Pin the wrapper to the binary it was generated from. The two share
          # the directive-file protocol above, which can drift between
          # versions, and PATH order is not guaranteed: a
          # `cargo install worktrunk` into ~/.cargo/bin would shadow this
          # build. The wrapper runs `''${WORKTRUNK_BIN:-wt}`, so this also
          # overrides PATH silently; to use another `wt`, set WORKTRUNK_BIN
          # per command or pass the wrapper's `--source` flag (`cargo run`).
          export WORKTRUNK_BIN=${lib.getExe worktrunk}
          source ${shellInit}
        ''
      );
    };
}

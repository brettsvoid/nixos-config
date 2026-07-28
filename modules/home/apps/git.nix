_: {
  flake.modules.homeManager.apps-git =
    { config, lib, ... }:
    let
      # The delta binary that core.pager / interactive.diffFilter point at.
      # `finalPackage` (not `package`) because with the built-in git
      # integration disabled below, home-manager hands back a delta wrapped
      # with `--config <generated>`, which is what carries `options`.
      delta = lib.getExe config.programs.delta.finalPackage;
    in
    {
      programs.git = {
        enable = true;
        lfs.enable = true;
        ignores = [
          "*~"
          "._*"
          "*.swp"
          "*.tmp"
          ".DS_Store"
          ".claude/settings.local.json"
        ];
        settings = {
          user.name = "Brett Henderson";
          user.email = "brettsvoid@gmail.com";
          init.defaultBranch = "main";
          pull.rebase = true;
          core.editor = "nvim";

          # Conflict markers keep the merge base between `|||||||` and `=======`,
          # so you can see what each side changed FROM rather than just the two
          # results. zdiff3 over plain diff3 because it hoists lines common to
          # both sides out of the conflict region — with diff3 those get printed
          # inside both halves, and you have to read past them to find the real
          # disagreement. Requires git >= 2.35.
          merge.conflictStyle = "zdiff3";

          # delta pages EVERY git command, matching the pre-nix chezmoi config.
          # Written by hand rather than via programs.delta.enableGitIntegration
          # — see the note in that block below.
          core.pager = delta;
          # Highlights hunks in `git add -p` / `git add -i`.
          interactive.diffFilter = "${delta} --color-only";
        };

        # Work identity, for repos under ~/work/projects only.
        #
        # `path` is a plain string, NOT a nix path, and there is deliberately
        # no `contents`: setting contents would make home-manager generate the
        # file into the nix store from this tracked, PUBLIC repo, which is
        # exactly where a work email address should not end up. The include
        # file is untracked and lives outside the repo, the same split as
        # ~/.config/zsh/local.zsh — see local.zsh.example.
        #
        # Git silently ignores an include whose path does not exist, so hosts
        # without the file just keep the personal identity above.
        #
        # Directory-based rather than matching on the remote URL: `tyto` is a
        # personal-identity repo that lives in the SAME GitHub org (irj-io) as
        # work's `irj-www`, so no `hasconfig:remote.*.url` pattern can separate
        # them. The path is where the rule actually lives.
        #
        # The trailing slash matters — `gitdir:` with one matches everything
        # BELOW the directory; without it, only the directory itself.
        includes = [
          {
            condition = "gitdir:~/work/projects/";
            path = "~/.config/git/work.inc";
          }
        ];
      };

      # Syntax-highlighting pager for diffs. Previously `delta` was installed by
      # profiles/code.nix but nothing ever pointed git at it, so it sat on PATH
      # unused — this is what actually wires it in.
      #
      # Lives under `programs.delta`, not `programs.git.delta`: home-manager
      # split it into its own module and left the old path as a renamed alias.
      # The module owns the package, which is why profiles/code.nix no longer
      # lists delta separately.
      programs.delta = {
        enable = true;

        # Deliberately OFF. The built-in integration writes
        # pager.{blame,diff,log,show}, and git resolves `pager.<cmd>` ahead of
        # `core.pager` — so delta would only ever handle those four commands
        # and a blanket core.pager would be dead config. Turning the
        # integration off leaves the git wiring to `settings` above, where
        # core.pager applies to everything.
        enableGitIntegration = false;

        # Delta settings go HERE, not in a `[delta]` section of the git config
        # — the wrapper's `--config` makes delta read this generated file
        # instead of gitconfig, so a `[delta]` block there would be ignored.
        options = {
          # n / N jump between files in the pager — the payoff on large diffs.
          navigate = true;
          line-numbers = true;
        };
      };
    };
}

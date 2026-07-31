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
          # `**/` is load-bearing. A pattern with a slash anywhere but the end
          # is anchored to the directory holding the ignore file, so a bare
          # `.claude/settings.local.json` matches only at a repository's root
          # and misses every nested one — subprojects, and the worktrees
          # apps-worktrunk creates. Verified with `git check-ignore`: without
          # the prefix, `sub/.claude/settings.local.json` is NOT ignored.
          #
          # The pre-nix ~/.gitignore_global had the prefix; it was dropped in
          # translation and only surfaced when diffing the migration backups.
          "**/.claude/settings.local.json"
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
        # SET THIS UP ON EVERY NEW HOST. That silence is the whole hazard, and
        # it is the same trap as `Include config.local` in apps-ssh: nix emits
        # the include, nothing creates the target, and there is no warning —
        # work commits just carry the personal address until someone notices.
        # It bit brett-m1-mbp: the file was simply never created there, and it
        # took a `--show-origin` check during the chezmoi retirement to spot
        # it. The work identity was recovered from the pre-nix
        # `~/.work.gitconfig`, which that host still had. Two lines:
        #
        #   printf '[user]\n\tname = ...\n\temail = ...\n' > ~/.config/git/work.inc
        #   chmod 600 ~/.config/git/work.inc
        #
        # Verify against an actual repo under the tree, not the parent:
        #
        #   git -C ~/work/projects/<repo> config --show-origin user.email
        #
        # Directory-based rather than matching on the remote URL: `tyto` is a
        # personal-identity repo that lives in the SAME GitHub org (irj-io) as
        # work's `irj-www`, so no `hasconfig:remote.*.url` pattern can separate
        # them. The path is where the rule actually lives.
        #
        # The trailing slash matters — `gitdir:` with one matches everything
        # BELOW the directory; without it, only the directory itself.
        #
        # Evaluated PER REPOSITORY, against the repo's own .git path. So this
        # reads as a failure but is not:
        #
        #   git -C ~/work/projects config user.email     -> brettsvoid@gmail.com
        #   git -C ~/work/projects/m2north-www ...       -> BrettH@m2north.com
        #
        # ~/work/projects is a plain directory with no .git, so there is
        # nothing for the condition to match and git falls back to the global
        # identity. Verify against an actual repo, never the parent. A fresh
        # `git init` or `git clone` under that tree picks up the work identity
        # immediately — confirmed, not assumed.
        #
        # The inverse is the real hazard and has no config fix: a work repo
        # cloned OUTSIDE ~/work/projects silently commits as the personal
        # identity. Inherent to matching on path. `user.useConfigOnly` would
        # turn it into a hard error, at the cost of every personal repo needing
        # an explicit identity first — not worth it here.
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

      # Retire a hand-written ~/.gitconfig on first activation.
      #
      # Everything above lands in ~/.config/git/config. git reads BOTH that and
      # ~/.gitconfig, in that order, so a leftover ~/.gitconfig silently wins
      # every conflict. On the mac mini that file set user.email to the work
      # address globally and installed credential helpers — it would have undone
      # the identity split, the delta pager and zdiff3 with no error and no
      # symptom beyond commits carrying the wrong address.
      #
      # home-manager cannot catch this itself: backupFileExtension only fires
      # where home-manager writes a file, and it never writes ~/.gitconfig. No
      # collision, no backup, no warning.
      #
      # Renamed rather than deleted, and never overwriting an existing rescue
      # copy, so this is reversible and safe to re-run. Once no machine has one
      # left, this block can go.
      home.activation.retireLegacyGitconfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
          _dest="$HOME/.gitconfig.pre-nix"
          if [ -e "$_dest" ]; then
            _dest="$_dest.$(date +%Y%m%d%H%M%S)"
          fi
          echo "apps-git: ~/.gitconfig would shadow ~/.config/git/config; moving it to $_dest"
          run mv $VERBOSE_ARG "$HOME/.gitconfig" "$_dest"
        fi
      '';
    };
}

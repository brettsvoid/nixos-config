_: {
  flake.modules.homeManager.apps-git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # The delta that core.pager / interactive.diffFilter use. `finalPackage`,
      # not `package`: with git integration off (below) it is delta wrapped
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
          # `**/` matters: a pattern with a slash before the end is anchored
          # to the repository root, so without it a nested
          # `sub/.claude/settings.local.json` is not ignored.
          "**/.claude/settings.local.json"
        ];
        settings = {
          user.name = "Brett Henderson";
          user.email = "brettsvoid@gmail.com";
          init.defaultBranch = "main";
          pull.rebase = true;
          core.editor = "nvim";

          # Conflict markers also show the merge base (between `|||||||` and
          # `=======`), so you see what each side changed from. zdiff3 rather
          # than diff3 moves lines common to both sides out of the conflict
          # region. Needs git >= 2.35.
          merge.conflictStyle = "zdiff3";

          # delta pages every git command. Set by hand rather than via
          # programs.delta.enableGitIntegration; see the note in that block.
          core.pager = delta;
          # Highlights hunks in `git add -p` / `git add -i`.
          interactive.diffFilter = "${delta} --color-only";

          # ghq clones into <root>/<host>/<owner>/<repo>, the layout the rest
          # of the config assumes (~/projects/github.com/brettsvoid/…); scratch
          # projects live in ~/projects/scratch. ghq.user is the owner for
          # `ghq create`, which otherwise uses the login name (brett).
          #
          # Work repos don't go through ghq: they must sit under
          # ~/work/projects for the identity include below to apply.
          ghq.root = "~/projects";
          ghq.user = "brettsvoid";
        };

        # Work identity, for repos under ~/work/projects only.
        #
        # `path` is a plain string and there is no `contents`, so the work
        # email never reaches the store or this public repo. The file is
        # untracked, like ~/.config/zsh/local.zsh (see local.zsh.example).
        #
        # Create it on every new host. Git silently ignores a missing include
        # (the same trap as `Include config.local` in apps-ssh), so work
        # commits would quietly carry the personal address:
        #
        #   printf '[user]\n\tname = ...\n\temail = ...\n' > ~/.config/git/work.inc
        #   chmod 600 ~/.config/git/work.inc
        #
        # `gitdir:` is matched per repository, so check from a repo inside the
        # tree; ~/work/projects itself has no .git and shows the personal
        # identity:
        #
        #   git -C ~/work/projects/<repo> config --show-origin user.email
        #
        # Matched on path, not remote URL, because the personal `tyto` and
        # work's `irj-www` share the irj-io GitHub org. The trailing slash
        # makes it match everything below the directory. The flip side: a work
        # repo cloned outside ~/work/projects commits as the personal identity.
        includes = [
          {
            condition = "gitdir:~/work/projects/";
            path = "~/.config/git/work.inc";
          }
        ];
      };

      # Reads ghq.root / ghq.user from the settings above.
      home.packages = [ pkgs.ghq ];

      # gh is also git's HTTPS credential helper for github.com and
      # gist.github.com (gitCredentialHelper, on by default), which `ghq get`
      # needs for private repos since ghq clones over HTTPS. `gh auth login`
      # with SSH chosen skips that wiring, and `gh auth setup-git` cannot
      # write to the store-linked git config.
      #
      # Each host needs `gh auth login` once; the token is not in nix. With no
      # keyring running (as on brett-desktop), gh stores it in plain text in
      # ~/.config/gh/hosts.yml.
      programs.gh = {
        enable = true;
        # Matches the SSH remotes already in use; the module default is https.
        settings.git_protocol = "ssh";
      };

      # Syntax-highlighting pager for diffs. `programs.git.delta` is the old,
      # renamed path. The module owns the package, so profiles/code.nix does
      # not list delta.
      programs.delta = {
        enable = true;

        # Off on purpose: the integration sets pager.{blame,diff,log,show},
        # and git prefers `pager.<cmd>` over `core.pager`, so delta would page
        # only those four. The git wiring is in `settings` above instead.
        enableGitIntegration = false;

        # Delta settings go here, not in a gitconfig `[delta]` section: the
        # wrapper's `--config` makes delta read this file instead.
        options = {
          # n / N jump between files in the pager — the payoff on large diffs.
          navigate = true;
          line-numbers = true;
        };
      };

      # Retire a hand-written ~/.gitconfig. git reads it after
      # ~/.config/git/config, so a leftover one silently overrides everything
      # above (identity, pager, zdiff3). backupFileExtension can't catch it:
      # home-manager never writes ~/.gitconfig. Renamed, never over an
      # earlier rescue copy, so it is reversible. Remove this block once no
      # machine has one left.
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

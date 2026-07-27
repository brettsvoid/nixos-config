_: {
  flake.modules.homeManager.shell-zsh = {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;

      history = {
        # 100k, matching the pre-nix config. The home-manager default is 10k,
        # which the migration silently adopted.
        size = 100000;
        save = 100000;

        ignoreAllDups = true; # subsumes ignoreDups (consecutive-only)

        # Every shell writes to $HISTFILE immediately and imports what other
        # shells wrote, so a command run in one tmux pane is recallable in the
        # next. The cost is that up-arrow is no longer "what I did in THIS
        # terminal" — history from every pane interleaves. Chosen deliberately:
        # the pre-nix config had `setopt sharehistory` commented out, and this
        # reverses that.
        #
        # Keep this line even though true is the home-manager default —
        # deleting it would NOT turn sharing off, and the explicit value is
        # what stops the question being re-litigated.
        #
        # If it is ever turned off, set `append = true` at the same time:
        # SHARE_HISTORY is currently the only thing preventing NO_APPEND_HISTORY
        # from truncating the file, so each shell would overwrite it at exit and
        # concurrent sessions would lose each other's history.
        share = true;

        # Not set here, but on by default and worth knowing: HIST_IGNORE_SPACE
        # (history.ignoreSpace) keeps any command typed with a leading space out
        # of the history file — the usual way to run a one-off command carrying
        # a token or password.
      };

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
    };
  };
}

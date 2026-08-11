_: {
  flake.modules.homeManager.shell-zsh =
    { lib, ... }:
    {
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

          # Just `git`. The pre-nix config also loaded aws, brew and python
          # (plus chezmoi, now obsolete, and the autosuggestions/completions/
          # syntax-highlighting plugins, which the options above provide
          # natively). Each was reviewed and dropped deliberately:
          #
          #   aws    — asp/agp/acp switch AWS_PROFILE for the whole shell.
          #            direnv (profile-code) already sets it per-directory,
          #            which is both narrower and automatic, and starship's
          #            `aws` module already renders the active profile, so the
          #            plugin's aws_prompt_info was redundant too.
          #   brew   — 36 aliases and nothing else. Worse than merely
          #            redundant: Homebrew here is declarative with
          #            `onActivation.cleanup = "uninstall"`, so anything `bi`
          #            installs imperatively is removed at the next
          #            activation. The plugin makes that mistake frictionless.
          #   python — 3 trivial aliases plus venv helpers, of which only
          #            auto_vrun mattered; it hooks chpwd to activate venvs on
          #            every cd, racing direnv for the same job.
          #
          # Lost with aws: `aws <TAB>` subcommand completion, which the plugin
          # sourced from aws_zsh_completer.sh. If that is ever wanted it can be
          # enabled directly — it does not need oh-my-zsh.
          plugins = [ "git" ];
        };

        # mkAfter (not the mkOrder 600-800 the other shell-* modules use):
        # those all render BEFORE oh-my-zsh and fzf's `--zsh` integration in
        # the generated .zshrc, and both of those bind keys. Neither claims
        # ^P/^N today — oh-my-zsh binds 67 keys, none of them these; fzf takes
        # only ^T, ^R and alt-C — but binding last is what keeps that true if
        # either changes.
        initContent = lib.mkAfter ''
          # Prefix-aware history search. With `git ch` already typed, ^P walks
          # only the history entries starting with `git ch`; zsh's default ^P
          # (up-line-or-history) ignores what you have typed and walks
          # everything. Complements ^R, which fzf rebinds to a fuzzy full-text
          # search over the whole history.
          bindkey '^p' history-search-backward
          bindkey '^n' history-search-forward

          # Tab lists the matches instead of inserting the first one, and
          # repeated Tab no longer cycles through inserting each candidate in
          # turn. Wanted here because autosuggestion is enabled: auto-inserting
          # on Tab competes with the inline suggestion already on screen.
          setopt noautomenu

          # Mouse reporting and the kitty keyboard protocol live in the
          # terminal emulator, not in the tty. `stty` cannot see them and
          # `stty sane` cannot clear them. A full-screen program turns them on
          # and is meant to turn them off as it exits.
          #
          # An ssh connection that dies breaks that contract twice over: the
          # remote program takes SIGHUP before it can write the reset, and the
          # link is already dead so nothing would cross it anyway. The local
          # terminal keeps both modes on for good. Mouse movement then reaches
          # the prompt as text (^[[<35;11;31M), keystrokes arrive CSI-u encoded
          # (^[[99;5u), and ctrl+c never reaches the line discipline as 0x03 —
          # so the window fills with "command not found" and cannot be typed
          # in or interrupted. Drag-selection breaks too, because the terminal
          # hands the drag to the application instead of selecting text.
          #
          # Clearing the modes before every prompt repairs the window on the
          # first prompt drawn after the drop. It has to run here, inside the
          # shell: herdr keeps this state per pane and replays it, so
          # resetting kitty (opt+cmd+r) never reaches herdr's copy.
          #
          # 1000/1002/1003 are the mouse tracking modes, 1006/1015/1016 the
          # report encodings, 1004 focus reporting. `>4;0m` clears xterm's
          # modifyOtherKeys. `=0;1u` sets every kitty keyboard flag to zero;
          # mode 1 means "set the bits given, reset the rest". Chosen over the
          # pop form (`<1u`) because a pop would discard a stack entry herdr
          # itself may own. 25h restores a cursor a dead TUI hid. Every one of
          # these touches input state only, and is a no-op when already off.
          _restore_terminal_input_modes() {
            [[ -t 1 ]] || return
            printf '\e[?1000l\e[?1002l\e[?1003l\e[?1004l\e[?1006l\e[?1015l\e[?1016l\e[>4;0m\e[=0;1u\e[?25h'
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _restore_terminal_input_modes

          # Leaving the alternate screen (1049l) belongs here, by hand, not in
          # precmd. At a prompt the shell is already on the primary screen, and
          # in a herdr pane the reset discards the visible buffer rather than
          # being ignored — so running it per prompt wipes the output of the
          # command that just finished. Bisected in a scratch pane: the ten
          # sequences above leave `cat` output intact, 1049l alone erases it.
          # A dead TUI that never left the alternate screen is rare and needs a
          # deliberate fix, so pay the screen clear only when asked.
          unstick-terminal() {
            _restore_terminal_input_modes
            printf '\e[?1049l'
          }
        '';
      };
    };
}

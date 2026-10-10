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
          # home-manager defaults to 10k.
          size = 100000;
          save = 100000;

          ignoreAllDups = true; # subsumes ignoreDups (consecutive-only)

          # Every shell writes history immediately and reads what others
          # wrote, so a command from one pane is recallable in the next;
          # up-arrow interleaves all panes. Explicit, though it is the
          # home-manager default, so deleting the line would not turn sharing
          # off.
          #
          # If you turn it off, also set `append = true`: home-manager sets
          # NO_APPEND_HISTORY, so each shell would overwrite the file at exit.
          share = true;

          # On by default (history.ignoreSpace): a command typed with a
          # leading space stays out of the history file, e.g. one carrying a
          # token.
        };

        oh-my-zsh = {
          enable = true;

          # Just `git`. Deliberately left out:
          #   aws    — direnv (profile-code) sets AWS_PROFILE per directory and
          #            starship shows it. Its `aws <TAB>` completion can be
          #            enabled without oh-my-zsh if wanted.
          #   brew   — only aliases, and Homebrew's `onActivation.cleanup =
          #            "uninstall"` removes whatever `bi` installs imperatively.
          #   python — its auto_vrun activates venvs on every cd, racing direnv.
          plugins = [ "git" ];
        };

        # mkAfter, not the mkOrder 600–800 the other shell-* modules use:
        # oh-my-zsh (800) and fzf's `--zsh` integration (910) both bind keys.
        # Neither takes ^P/^N today; binding last keeps it that way.
        initContent = lib.mkAfter ''
          # Prefix-aware history search: with `git ch` typed, ^P/^N walk only
          # entries starting `git ch`. ^R stays fzf's fuzzy search.
          bindkey '^p' history-search-backward
          bindkey '^n' history-search-forward

          # Repeated Tab keeps listing matches instead of inserting and
          # cycling through them, which would compete with the inline
          # autosuggestion.
          setopt noautomenu

          # Reset terminal input modes before every prompt. A full-screen
          # program that dies with its ssh link never turns off mouse
          # reporting or the kitty keyboard protocol, so mouse moves and keys
          # then reach the prompt as escape codes and ctrl+c stops working.
          # The modes live in the emulator, out of `stty sane`'s reach. It
          # must run in the shell: herdr keeps this state per pane, so
          # resetting kitty never reaches herdr's copy.
          #
          # ?1000/1002/1003 mouse tracking, ?1006/1015/1016 report encodings,
          # ?1004 focus reporting, >4;0m xterm modifyOtherKeys, =0;1u every
          # kitty keyboard flag to zero (not the `<1u` pop, which could drop a
          # stack entry herdr owns), ?25h show the cursor. Each is a no-op
          # when already off.
          _restore_terminal_input_modes() {
            [[ -t 1 ]] || return
            printf '\e[?1000l\e[?1002l\e[?1003l\e[?1004l\e[?1006l\e[?1015l\e[?1016l\e[>4;0m\e[=0;1u\e[?25h'
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _restore_terminal_input_modes

          # By hand, as it also leaves the alternate screen (1049l). Not in
          # precmd: in a herdr pane 1049l discards the visible buffer, wiping
          # the last command's output.
          unstick-terminal() {
            _restore_terminal_input_modes
            printf '\e[?1049l'
          }
        '';
      };
    };
}

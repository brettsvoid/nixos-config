{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 10;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = vim-tmux-navigator;
        extraConfig = "set -g @vim-tmux-navigator-no-mappings 1";
      }
      {
        plugin = catppuccin;
        extraConfig = "set -g @catppuccin_flavour 'macchiato'";
      }
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
      }
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
      tmux-fzf
    ];

    extraConfig = ''
      # True color support
      set-option -ga terminal-overrides ",*-256color:Tc"

      # Allow passthrough for Kitty graphics protocol (required for image.nvim)
      set -g allow-passthrough on
      set -gq allow-passthrough on

      # Bind <leader>r to source tmux config
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf

      # Vim style pane selection
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Split panes with visual keys (open in current directory)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Resize mode: prefix + R to enter, h/j/k/l to resize, Enter/Escape to exit
      bind R switch-client -T resize
      bind -T resize h resize-pane -L 5 \; switch-client -T resize
      bind -T resize j resize-pane -D 5 \; switch-client -T resize
      bind -T resize k resize-pane -U 5 \; switch-client -T resize
      bind -T resize l resize-pane -R 5 \; switch-client -T resize
      bind -T resize Enter switch-client -T root
      bind -T resize Escape switch-client -T root

      # Pane base index
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Alt+Arrow to switch panes (with vim-tmux-navigator for seamless Neovim integration)
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
      bind -n M-Left if-shell "$is_vim" 'send-keys M-Left' 'select-pane -L'
      bind -n M-Down if-shell "$is_vim" 'send-keys M-Down' 'select-pane -D'
      bind -n M-Up if-shell "$is_vim" 'send-keys M-Up' 'select-pane -U'
      bind -n M-Right if-shell "$is_vim" 'send-keys M-Right' 'select-pane -R'

      # Shift arrow to switch windows
      bind -n S-Left  previous-window
      bind -n S-Right next-window

      # Shift Alt vim keys to switch windows
      bind -n M-H previous-window
      bind -n M-L next-window

      # Status bar position
      set -g status-position bottom
    '';
  };
}

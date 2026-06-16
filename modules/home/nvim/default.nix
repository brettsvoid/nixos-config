# Neovim with full LSP/formatter/linter toolchain. Lazy.nvim manages plugins
# at runtime; the lua tree under ./config is the static source of truth.
#
# IMPORTANT: ~/.config/nvim itself stays a real directory so its *children*
# can be managed individually (each as an mkOutOfStoreSymlink → live repo
# path). Editing a .lua file in the repo updates nvim immediately; no rebuild
# needed. lazy-lock.json is one such managed child, so `:Lazy update` writes
# the pinned commits straight back into the repo.
_: {
  flake.modules.homeManager.nvim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      configRoot = "${config.home.homeDirectory}/nixos-config/modules/home/nvim/config";

      # Treesitter parsers, version-locked to this flake's nixpkgs instead of
      # compiled at runtime by `:TSUpdate`. Each nvim-treesitter-parsers.<lang>
      # ships parser/<lang>.so; symlinkJoin collapses them into one parser/
      # dir we drop onto nvim's runtimepath (see xdg.configFile below). The
      # nvim-treesitter plugin (managed by lazy, branch=main) still supplies
      # the queries and ft→lang aliases — only the compiled grammars move to
      # Nix. Parsers build against this nixpkgs' tree-sitter, so their ABI
      # stays in lockstep with the neovim it also builds. This is the single
      # source of truth for which languages get a parser.
      treesitterParsers = pkgs.symlinkJoin {
        name = "nvim-treesitter-parsers";
        paths = map (l: pkgs.vimPlugins.nvim-treesitter-parsers.${l}) [
          "bash"
          "c"
          "css"
          "csv"
          "diff"
          "dockerfile"
          "git_config"
          "git_rebase"
          "gitattributes"
          "gitcommit"
          "gitignore"
          "go"
          "gomod"
          "gosum"
          "hcl"
          "html"
          "ini"
          "javascript"
          "json"
          "lua"
          "luadoc"
          "markdown"
          "markdown_inline"
          "mermaid"
          "nix"
          "pem"
          "php"
          "python"
          "query"
          "rust"
          "sql"
          "ssh_config"
          "terraform"
          "tmux"
          "toml"
          "tsx"
          "typescript"
          "vim"
          "vimdoc"
          "xml"
          "yaml"
        ];
      };
    in
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        vimdiffAlias = true;

        # Drop the Ruby and Python providers — config is Lua-only and the
        # only Python touchpoint (nvim-dap-python) shells out to an
        # external interpreter rather than using the in-process provider.
        # Adopts the home-manager 26.05 default early; without these our
        # `home.stateVersion = "24.11"` triggers a deprecation warning.
        withRuby = false;
        withPython3 = false;

        extraPackages =
          with pkgs;
          [
            # Build deps (treesitter parser compilation, plugin builds)
            gcc
            gnumake
            cmake
            nodejs
            python3
            git
            curl
            unzip
            luarocks
            lua5_1

            # Language toolchains
            go
            rustc
            cargo

            # LSP servers (replaces Mason on NixOS)
            lua-language-server
            nil # Nix (static lints)
            nixd # Nix (evaluation-driven completion)
            typescript-language-server
            pyright
            gopls
            rust-analyzer
            bash-language-server
            terraform-ls
            dockerfile-language-server
            vscode-langservers-extracted # HTML/CSS/JSON/ESLint
            emmet-ls
            tailwindcss-language-server
            biome
            glsl_analyzer
            yaml-language-server

            # Formatters
            stylua
            prettierd
            prettier
            black
            isort
            gofumpt
            goimports-reviser
            golines
            shfmt
            taplo
            rustfmt
            nixfmt-rfc-style # provides the `nixfmt` binary conform calls

            # Linters
            eslint_d
            selene
            shellcheck
            tflint

            # Tools used by plugins
            ripgrep
            fd
            lazygit
            # tree-sitter CLI dropped: parsers come prebuilt from Nix
            # (treesitterParsers above), so nothing compiles grammars at
            # runtime. gcc/gnumake/cmake are kept for other plugin builds.
          ]
          # Wayland clipboard helper — Linux-only (Darwin uses pbcopy/pbpaste)
          ++ lib.optionals pkgs.stdenv.isLinux [ wl-clipboard ];
      };

      xdg.configFile = {
        "nvim/init.lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/init.lua";
        # Pinned plugin versions, tracked in-repo. lazy.nvim writes *through*
        # this symlink on `:Lazy update`, so plugin bumps show up as a repo diff
        # and new machines clone the exact same commits.
        "nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lazy-lock.json";
        "nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lua";
        "nvim/lsp".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lsp";
        "nvim/queries".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/queries";
        "nvim/README.md".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/README.md";
        # Prebuilt, version-locked parsers on the runtimepath. A plain store
        # symlink (not mkOutOfStoreSymlink) since these are immutable Nix
        # artifacts, never edited in-repo. ~/.config/nvim is on rtp, so
        # vim.treesitter.start finds parser/<lang>.so here.
        "nvim/parser".source = "${treesitterParsers}/parser";
      };
    };
}

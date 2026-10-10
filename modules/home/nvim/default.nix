# Neovim with its LSP/formatter/linter toolchain; lazy.nvim manages plugins at
# runtime from the Lua tree under ./config.
#
# ~/.config/nvim stays a real directory so each child can be linked on its own,
# mostly as mkOutOfStoreSymlinks to the live repo: edits apply without a rebuild.
{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.nvim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      configRoot = "${config.home.homeDirectory}/${repoDir}/modules/home/nvim/config";

      # Treesitter parsers from this flake's nixpkgs (ABI matches its neovim),
      # not `:TSUpdate`. This is the one list of languages that get a parser.
      # The nvim-treesitter plugin (lazy, branch=main) adds ft→lang aliases and
      # indentexpr only: main puts its queries on the rtp via :TSInstall, which
      # this setup never runs.
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
          # No "tmux": nixpkgs dropped nvim-treesitter-parsers.tmux. Re-add if it
          # returns.
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

        # No Ruby/Python providers: the config is Lua-only and nvim-dap-python
        # runs an external interpreter. This is home-manager's 26.05 default;
        # setting it silences the warning from home.stateVersion "24.11".
        withRuby = false;
        withPython3 = false;

        extraPackages =
          with pkgs;
          [
            # Build deps for plugin build hooks. No tree-sitter CLI: parsers
            # come prebuilt (treesitterParsers above).
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
            nixfmt # RFC style

            # Linters
            eslint_d
            selene
            shellcheck
            tflint

            # Tools used by plugins
            ripgrep
            fd
            lazygit
            # Go tools gopher.nvim runs from PATH, in place of its `go install`
            # build hook. json2go (:GoJson2Go) isn't in nixpkgs.
            gomodifytags
            impl
            gotests
            iferr
          ]
          # Wayland clipboard helper — Linux-only (Darwin uses pbcopy/pbpaste)
          ++ lib.optionals pkgs.stdenv.isLinux [ wl-clipboard ];
      };

      xdg.configFile = {
        "nvim/init.lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/init.lua";
        # Pinned plugin commits. `:Lazy update` writes through this symlink, so
        # bumps land as a repo diff and every machine gets the same commits.
        "nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lazy-lock.json";
        "nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lua";
        "nvim/lsp".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lsp";
        "nvim/queries".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/queries";
        "nvim/README.md".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/README.md";
        # Plain store symlink (Nix-built, never edited in-repo). ~/.config/nvim
        # is on the rtp, so vim.treesitter.start finds parser/<lang>.so here.
        "nvim/parser".source = "${treesitterParsers}/parser";
      };
    };
}

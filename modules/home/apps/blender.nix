# Blender from nixpkgs rather than the Homebrew cask. On darwin the package
# ships Blender.app (plus a `blender` wrapper), which home-manager's
# targets.darwin.linkApps symlinks into ~/Applications/Home Manager Apps.
# The cask would also bring a `command_wrapper` artifact, the type that broke
# `brew bundle` on the mini (see modules/hosts/brett-mac-mini.nix).
#
# Preferences live outside the store, in
# ~/Library/Application Support/Blender/<major.minor> (~/.config/blender on
# Linux).
#
# On Linux this is the build without CUDA (nixpkgs' cudaSupport is off), so
# Cycles renders on the CPU only. cache.nixos.org has no CUDA build, so
# turning it on means compiling Blender locally.
#
# MCP for Blender (https://github.com/ahujasid/mcp-for-blender) lets Claude
# Code drive Blender: a user-scope MCP server run by uvx, and the addon it
# talks to over localhost:9876. Both come from the same pinned wheel, as the
# addon's protocol version must match the server's. Enabling the addon is a
# one-off in Preferences → Add-ons ("Interface: MCP for Blender"); after that
# it starts its socket server whenever Blender opens. To upgrade, bump
# mcpVersion and the hash, not the addon panel's Update button, which would
# leave the server behind.
_: {
  flake.modules.homeManager.apps-blender =
    { lib, pkgs, ... }:
    let
      mcpVersion = "2.2.7";

      mcpWheel = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/py3/m/mcp-for-blender/mcp_for_blender-${mcpVersion}-py3-none-any.whl";
        hash = "sha256-L9Ktb5ME+CFxZ8CNxhwYZCvAip9D+yw5iO7khRZARyw=";
      };

      mcpAddon = pkgs.runCommand "mcp-for-blender-addon-${mcpVersion}" {
        nativeBuildInputs = [ pkgs.unzip ];
      } "unzip -p ${mcpWheel} blender_mcp/bundled/addon.py >$out";

      configBase =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "Library/Application Support/Blender"
        else
          ".config/blender";
    in
    {
      home.packages = [ pkgs.blender ];

      # The name `uvx mcp-for-blender install-addon` uses, so the server's
      # startup check finds it.
      home.file."${configBase}/${lib.versions.majorMinor pkgs.blender.version}/scripts/addons/blender_mcp.py".source =
        mcpAddon;

      local.claudeCode.mcpServers.blender = {
        type = "stdio";
        command = lib.getExe' pkgs.uv "uvx";
        args = [ "mcp-for-blender==${mcpVersion}" ];
        env.DISABLE_TELEMETRY = "true";
      };
    };
}

# Google Chrome on the NixOS hosts. The Macs install it as a Homebrew cask
# (modules/hosts/brett-mac-mini.nix), so this module is for Linux only.
#
# Firefox stays the default browser. Home Manager cannot install Chrome
# extensions on Linux (Chrome reads them only from system directories), so
# extensions and settings stay in Chrome's own profile sync.
_: {
  flake.modules.homeManager.apps-google-chrome = {
    programs.google-chrome.enable = true;
  };
}

#!/usr/bin/env bash
# One-command bootstrap. Usage: bootstrap.sh [hostname]
# Detects platform, ensures Nix is installed, clones the repo,
# and runs the appropriate rebuilder.
set -euo pipefail

REPO_URL="https://github.com/brettsvoid/nixos-config.git"
REPO_DIR="${HOME}/nixos-config"
HOST="${1:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
uname_s="$(uname -s)"

echo "==> Bootstrap target: $HOST ($uname_s)"

# 1. Ensure nix
if ! command -v nix >/dev/null 2>&1; then
  if [[ "$uname_s" == "Darwin" ]]; then
    if [[ -d /nix && -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist ]]; then
      echo "==> Existing non-Determinate nix detected; sourcing daemon"
      # shellcheck disable=SC1091
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    else
      # Upstream Nix, NOT Determinate. nix-darwin manages Nix here (nix.enable
      # defaults true) and its activation check aborts with "Determinate
      # detected" if /usr/local/bin/determinate-nixd exists — see nix-darwin's
      # modules/system/checks.nix, gated on `mkIf config.nix.enable`. To adopt
      # Determinate instead, set nix.enable = false (and lose the `nix.*`
      # options: nix.settings and nix.optimise in system/darwin/common.nix
      # would have to move to /etc/nix/nix.custom.conf, outside this repo).
      #
      # `--prefer-upstream-nix` is REQUIRED, not belt-and-braces. Omitting it
      # used to give upstream Nix, but as of nix-installer v3.21.8 Determinate
      # is the default — a plain `install` puts the machine straight into the
      # state that aborts activation. Recovery is
      # `sudo /nix/nix-installer uninstall` followed by a reinstall with the
      # flag. (Equivalent env var: NIX_INSTALLER_PREFER_UPSTREAM_NIX=1.)
      echo "==> Installing Nix (upstream)"
      curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --prefer-upstream-nix
      # shellcheck disable=SC1091
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  fi
fi

# 1b. Refuse to continue against a Determinate install. Deliberately OUTSIDE
# the block above: the common case is a machine that already has Determinate
# Nix on PATH, where none of the install branches run at all. Failing here
# with a fix is friendlier than failing at activation with "Determinate
# detected", which happens after a full build.
if [[ "$uname_s" == "Darwin" && -e /usr/local/bin/determinate-nixd ]]; then
  echo "==> ERROR: Determinate Nix detected (/usr/local/bin/determinate-nixd)." >&2
  echo "    nix-darwin refuses to activate while nix.enable = true, because" >&2
  echo "    Determinate manages the same daemon and /etc/nix/nix.conf." >&2
  echo "" >&2
  echo "    Fix: sudo /nix/nix-installer uninstall" >&2
  echo "         then re-run this script (it reinstalls with --prefer-upstream-nix)." >&2
  echo "    Alternatively, keep Determinate and set nix.enable = false." >&2
  exit 1
fi

# 2. Ensure flakes are enabled in user nix.conf
mkdir -p "${HOME}/.config/nix"
if ! grep -q 'experimental-features' "${HOME}/.config/nix/nix.conf" 2>/dev/null; then
  echo 'experimental-features = nix-command flakes' >> "${HOME}/.config/nix/nix.conf"
fi

# 3. Repo
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "==> Cloning $REPO_URL → $REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "==> Updating existing repo at $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only || true
fi

# 4. Switch
case "$uname_s" in
  Darwin)
    echo "==> Running darwin-rebuild switch"
    sudo nix run nix-darwin/master -- switch --flake "$REPO_DIR#$HOST"
    ;;
  Linux)
    echo "==> Running nixos-rebuild switch"
    sudo nixos-rebuild switch --flake "$REPO_DIR#$HOST"
    ;;
  *)
    echo "Unsupported OS: $uname_s" >&2
    exit 1
    ;;
esac

echo ""
echo "==> Bootstrap complete for $HOST."
echo "==> Future updates: \`nix-rebuild\` (alias)."

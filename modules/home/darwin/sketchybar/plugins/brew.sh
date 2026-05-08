#!/usr/bin/env sh

# Set Homebrew environment variables to avoid CPU detection issues
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_MAKE_JOBS=4
export HOMEBREW_CURL_RETRIES=0
export HOMEBREW_DOWNLOAD_CONCURRENCY=1

source "$HOME/.config/colors.sh"

COUNT="$(brew outdated | wc -l | tr -d ' ')"

COLOR=$COLOR_RED

case "$COUNT" in
[3-5][0-9])
  COLOR=$COLOR_ORANGE
  ;;
[1-2][0-9])
  COLOR=$COLOR_YELLOW
  ;;
[1-9])
  COLOR=$COLOR_WHITE
  ;;
0)
  COLOR=$COLOR_GREEN
  COUNT=✔︎
  ;;
esac


sketchybar -m --set $NAME label=$COUNT icon.color=$COLOR

#!/bin/sh
set -eu

sock="$HOME/.cache/edgebar/dev.sock"

usage() {
  cat >&2 <<'EOF'
usage:
  dev.sh eval '<js>'     run <js> in the bar's WebView and print its result as JSON
  dev.sh snap <out.png>  write a PNG of the bar's WebView over its native frame
  dev.sh type '<text>'   post <text> as key presses to edgebar's key window;
                         ESC (\033) is Escape and DEL (\177) is Backspace
EOF
  exit 2
}

[ $# -eq 2 ] || usage
case $1 in
eval) request="eval $2" ;;
type) request="type $2" ;;
snap)
  dir=$(cd "$(dirname "$2")" && pwd)
  request="snap $dir/$(basename "$2")"
  ;;
*) usage ;;
esac

if [ ! -S "$sock" ]; then
  echo "dev.sh: no $sock; is a debug edgebar running?" >&2
  exit 1
fi

reply=$(printf '%s' "$request" | nc -U "$sock")
printf '%s\n' "$reply"
case $reply in
ERR* | "") exit 1 ;;
esac

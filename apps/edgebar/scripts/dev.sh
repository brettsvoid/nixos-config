#!/bin/sh
# Drive a running debug edgebar through its developer socket (devtools.rs).
#
#   scripts/dev.sh eval '<js>'      print the JSON of what <js> evaluates to in
#                                   the main bar WebView
#   scripts/dev.sh snap <out.png>   write the main display as edgebar draws it
#
# Prints the reply and exits non-zero when it is ERR.
set -eu

sock="$HOME/.cache/edgebar/dev.sock"

usage() {
  echo "usage: dev.sh eval '<js>' | dev.sh snap <out.png>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
case $1 in
eval) request="eval $2" ;;
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

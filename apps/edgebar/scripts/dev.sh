#!/bin/sh
set -eu

sock="$HOME/.cache/edgebar/dev.sock"

usage() {
  echo "usage: dev.sh eval '<js>' | dev.sh snap <out.png> | dev.sh type '<text>'" >&2
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

#!/bin/sh
set -eu

out=${1:?usage: snap-states.sh <outdir> [tab...]}
shift
mkdir -p "$out"
dev="$(dirname "$0")/dev.sh"

ev() { "$dev" eval "$1" >/dev/null; }
snap() { "$dev" snap "$(cd "$out" && pwd)/$1.png" >/dev/null && echo "$out/$1.png"; }
wait_for() {
  i=0
  while [ "$("$dev" eval "$1")" != "true" ] && [ $i -lt 40 ]; do
    sleep 0.2
    i=$((i + 1))
  done
  sleep 0.4
}
state() { echo "document.querySelector('$1').dataset.state === '$2'"; }

close_notch() {
  if [ "$("$dev" eval "$(state .notch-drawer closed)")" != "true" ]; then
    ev 'document.querySelector("#notch .notch-row").click(), 1'
    wait_for "$(state .notch-drawer closed)"
  fi
}

close_notch
snap idle

if [ $# -eq 0 ]; then
  set -- $("$dev" eval '[...document.querySelectorAll(".rail-tab[data-to]")].map(b => b.dataset.to).join(" ")' | tr -d '"')
fi

ev 'document.querySelector("#notch .notch-row").click(), 1'
wait_for "$(state .notch-drawer open)"
for tab in "$@"; do
  ev "document.querySelector('.rail-tab[data-to=\"$tab\"]').click(), 1"
  sleep 2.5
  snap "notch-$tab"
done
close_notch

ev 'document.querySelector("#ctl-btn").click(), 1'
wait_for "$(state .ctl-panel open)"
snap controls
ev 'document.querySelector("#ctl-btn").click(), 1'
wait_for "$(state .ctl-panel closed)"

ev 'document.querySelector("#launcher-btn").click(), 1'
wait_for "$(state .menu-panel open)"
snap launcher
ev 'document.querySelector("#launcher-btn").click(), 1'
wait_for "$(state .menu-panel closed)"

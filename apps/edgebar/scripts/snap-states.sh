#!/bin/sh
# Walk the live bar through each state and snapshot it into <outdir>:
# idle, the notch on each rail tab, the controls drawer and the launcher drawer.
# Needs a debug build (see dev.sh). Usage: snap-states.sh <outdir> [tab...]
# The tabs default to every rail button that opens a view.
set -eu

out=${1:?usage: snap-states.sh <outdir> [tab...]}
shift
mkdir -p "$out"
dev="$(dirname "$0")/dev.sh"

ev() { "$dev" eval "$1" >/dev/null; }
snap() { "$dev" snap "$(cd "$out" && pwd)/$1.png" >/dev/null && echo "$out/$1.png"; }
# Poll a JS condition (up to ~8 s) instead of sleeping a fixed time: opening the
# controls drawer waits on get_volume, which can take seconds.
wait_for() {
  i=0
  while [ "$("$dev" eval "$1")" != "true" ] && [ $i -lt 40 ]; do
    sleep 0.2
    i=$((i + 1))
  done
  sleep 0.4
}
# A drawer's state, which main.ts sets once its spring has settled.
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

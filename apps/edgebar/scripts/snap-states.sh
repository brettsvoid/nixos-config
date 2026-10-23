#!/bin/sh
# Walk the live bar through each state and snapshot it into <outdir>:
# idle, the notch on each rail tab, the controls drawer and the launcher.
# Needs a debug build (see dev.sh). Usage: snap-states.sh <outdir> [tab...]
# The tabs default to every rail button that opens a view.
set -eu

out=${1:?usage: snap-states.sh <outdir> [tab...]}
shift
mkdir -p "$out"
dev="$(dirname "$0")/dev.sh"

ev() { "$dev" eval "$1" >/dev/null; }
snap() { "$dev" snap "$(cd "$out" && pwd)/$1.png" >/dev/null && echo "$out/$1.png"; }
notch_open() { "$dev" eval 'document.querySelector("#notch").offsetHeight > 48'; }

close_notch() {
  if [ "$(notch_open)" = "true" ]; then
    ev 'document.querySelector("#notch .notch-row").click(), 1'
    sleep 1.2
  fi
}

close_notch
snap idle

if [ $# -eq 0 ]; then
  set -- $("$dev" eval '[...document.querySelectorAll(".rail-tab[data-to]")].map(b => b.dataset.to).join(" ")' | tr -d '"')
fi

ev 'document.querySelector("#notch .notch-row").click(), 1'
sleep 1.2
for tab in "$@"; do
  ev "document.querySelector('.rail-tab[data-to=\"$tab\"]').click(), 1"
  sleep 2.5
  snap "notch-$tab"
done
close_notch

ev 'document.querySelector("#ctl-btn").click(), 1'
sleep 1.2
snap controls
ev 'document.querySelector("#ctl-btn").click(), 1'
sleep 1

ev 'document.querySelector("#launcher-btn").click(), 1'
sleep 1.2
snap launcher
ev 'document.querySelector("#launcher-btn").click(), 1'
sleep 1

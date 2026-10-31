# custom-shell-or <shortcut> <fallback...>: fires one of the custom shell's global
# shortcuts (a drawer, or the lock) while that shell has it registered, and runs the
# fallback under the other shells. It keeps Super+R, Super+/ and Super+L working
# everywhere until the custom shell is the session's shell (custom-shell issue 22).
drawer=$1
shift
if hyprctl globalshortcuts -j | jq -e --arg name "custom-shell:$drawer" 'any(.[]; .name == $name)' >/dev/null; then
  # Safe inside the Lua quotes: jq has just matched it to a registered shortcut's name.
  exec hyprctl dispatch "hl.dsp.global(\"custom-shell:$drawer\")"
fi
exec "$@"

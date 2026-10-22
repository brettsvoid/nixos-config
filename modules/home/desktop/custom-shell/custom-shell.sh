# custom-shell [target function [argument...]]: calls a function of the running custom
# shell (quickshell/ipc/Ipc.qml), such as `custom-shell drawers toggle launcher`. With no
# arguments it lists every target and its functions.
# A function that takes a name or value replies "" when done, or "error: ..." when it
# refused. That goes to stderr and the exit status is 1, which `qs ipc call` alone does
# not do: it prints its own refusals ("Target not found.", a wrong argument count or
# type) to stdout and exits 0 whatever happens, so those are given the same treatment.
# No shell running is qs's own failure, with its own status.
# custom-shell.nix puts before this: $qs. --any-display lets it run where there is no
# Wayland display, as in a systemd service.
if [ $# -eq 0 ]; then
  exec "$qs" ipc -c custom-shell --any-display show
fi

# qs reads an argument that starts with [ as its own list syntax and drops the
# brackets, which breaks a JSON list; a space in front keeps them. `call --` because
# qs reads the function name "show" (osd show) as its own subcommand otherwise.
args=()
for arg in "$@"; do
  case "$arg" in
    \[*) arg=" $arg" ;;
  esac
  args+=("$arg")
done

reply=$("$qs" ipc -c custom-shell --any-display call -- "${args[@]}") || exit
case "$reply" in
  # The messages are Quickshell's (src/io/ipccomm.cpp).
  "error:"* | "Target not found."* | "Function not found."* | "Not ready to accept queries yet."* | "Unable to parse argument "* | "Too few arguments"* | "Too many arguments"*)
    echo "$reply" >&2
    exit 1
    ;;
  "") ;;
  *) echo "$reply" ;;
esac

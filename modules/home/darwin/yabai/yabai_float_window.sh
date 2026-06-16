#!/usr/bin/env bash

# Check if there is exactly one window belonging to the process of the window that was just
# created and unfloat it. This expects these processes to be set to manage=off initially.
# That will keep the float window sizes initialising as fullscreen.
if yabai -m query --windows \
    | jq -er '
        # Find the pid for the current window
        map(select(.id == (env.YABAI_WINDOW_ID | tonumber)).pid)[0] as $pid
        # Count how many windows share that pid
        | map(select(.pid == $pid)) | length == 1
    ' >  /dev/null
then
    # This is the only window with this pid — treat it as the main/root window
    yabai -m window "${YABAI_WINDOW_ID}" --toggle float
fi

# Always focus the new window (hybrid apps are excluded from the general auto-focus signal)
yabai -m window "${YABAI_WINDOW_ID}" --focus

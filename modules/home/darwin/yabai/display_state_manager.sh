#!/usr/bin/env bash

STATE_DIR="/tmp/yabai_states"
DIRTY_FLAG="/tmp/yabai_dirty_flag"

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Generate profile key from current display configuration
get_profile_key() {
    # Get sorted list of display UUIDs to create a consistent profile key
    yabai -m query --displays | jq -r '[.[].uuid] | sort | join("-")' | md5
}

# Save state for current display profile (called by window_focused if dirty)
save_state() {
    # Only save if dirty flag is set
    if [[ ! -f "$DIRTY_FLAG" ]]; then
        return
    fi

    # Debounce: if another save fires within 0.3s, let it take over
    local debounce_file="/tmp/yabai_save_debounce"
    echo $$ > "$debounce_file"
    sleep 0.3
    if [[ "$(cat "$debounce_file" 2>/dev/null)" != "$$" ]]; then
        return
    fi

    # Get current profile key
    profile_key=$(get_profile_key)

    if [[ -z "$profile_key" ]]; then
        echo "$(date): Failed to generate profile key" >> /tmp/yabai_display_debug.log
        return
    fi

    state_file="$STATE_DIR/state_${profile_key}.json"
    display_file="$STATE_DIR/displays_${profile_key}.json"

    # Save window states and display info for this profile
    yabai -m query --windows > "$state_file"
    yabai -m query --displays > "$display_file"

    # Clear dirty flag
    rm -f "$DIRTY_FLAG"

    window_count=$(jq length "$state_file" 2>/dev/null || echo "0")
    echo "$(date): Saved profile $profile_key ($window_count windows)" >> /tmp/yabai_display_debug.log
}

# Restore state for current display profile
restore_state() {
    # Get current profile key
    profile_key=$(get_profile_key)

    if [[ -z "$profile_key" ]]; then
        echo "$(date): Failed to generate profile key for restore" >> /tmp/yabai_display_debug.log
        return
    fi

    state_file="$STATE_DIR/state_${profile_key}.json"
    display_file="$STATE_DIR/displays_${profile_key}.json"

    if [[ ! -f "$state_file" ]] || [[ ! -f "$display_file" ]]; then
        echo "$(date): No saved state for profile $profile_key" >> /tmp/yabai_display_debug.log
        return
    fi

    # Wait for the display to fully initialize
    sleep 2

    # Get current display info
    current_displays=$(yabai -m query --displays)
    saved_displays=$(cat "$display_file")

    # Build a mapping of saved display UUID -> current display index
    declare -A uuid_to_current_index

    while IFS= read -r saved_display; do
        uuid=$(echo "$saved_display" | jq -r '.uuid')
        saved_index=$(echo "$saved_display" | jq -r '.index')

        # Find this UUID in current displays
        current_index=$(echo "$current_displays" | jq -r ".[] | select(.uuid == \"$uuid\") | .index")

        if [[ -n "$current_index" ]]; then
            uuid_to_current_index[$saved_index]=$current_index
        fi
    done < <(echo "$saved_displays" | jq -c '.[]')

    # Get current windows
    current_windows=$(yabai -m query --windows)

    # Restore window positions
    restored_count=0
    while IFS= read -r saved_window; do
        window_id=$(echo "$saved_window" | jq -r '.id')
        saved_display_index=$(echo "$saved_window" | jq -r '.display')
        app=$(echo "$saved_window" | jq -r '.app')

        # Check if this window still exists
        current_window=$(echo "$current_windows" | jq ".[] | select(.id == $window_id)")

        if [[ -n "$current_window" ]]; then
            current_display_index=$(echo "$current_window" | jq -r '.display')

            # Map the saved display index to current display index
            target_display_index=${uuid_to_current_index[$saved_display_index]}

            if [[ -n "$target_display_index" ]] && [[ "$current_display_index" != "$target_display_index" ]]; then
                # Move window to correct display
                yabai -m window "$window_id" --display "$target_display_index" 2>/dev/null && {
                    echo "$(date): Restored $app (ID: $window_id) to display $target_display_index" >> /tmp/yabai_display_debug.log
                    ((restored_count++))
                }
            fi
        fi
    done < <(jq -c '.[]' "$state_file")

    echo "$(date): Restored profile $profile_key ($restored_count windows moved)" >> /tmp/yabai_display_debug.log
}

case "$1" in
    save)
        save_state
        ;;
    restore)
        restore_state
        ;;
    *)
        echo "Usage: $0 {save|restore}"
        exit 1
        ;;
esac

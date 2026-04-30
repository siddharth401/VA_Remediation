#!/bin/bash
# manage_custom_services.sh
# This script discovers, stops, and starts custom services managed by the `egold` user
# by locating the specific TomEE startup/shutdown scripts within the user's profile aliases.

ACTION=$1
STATE_FILE="/tmp/va_remediation_stopped_services.txt"

if [ -z "$ACTION" ]; then
    echo "Usage: $0 {stop|start}"
    exit 1
fi

if [ "$ACTION" == "stop" ]; then
    echo "Starting Auto-Discovery of running services..."
    > "$STATE_FILE"

    # 1. Find all running Java processes owned by egold (or specific app processes)
    # 2. Extract their directory paths
    # For this skeleton, we assume we find the home directories where the instances live:

    # Example logic: Find directories containing the known shutdown script
    # This simulates dynamically finding active profiles via aliases or running processes
    FOUND_PROFILES=$(find /home/egold /opt/egold -maxdepth 4 -name "Multiple_Tomcat_Instances_Shutdown.sh" 2>/dev/null)

    for SCRIPT in $FOUND_PROFILES; do
        BASE_DIR=$(dirname "$SCRIPT")
        echo "Discovered running service instance at: $BASE_DIR"

        # Save the corresponding START script to the state file for later
        START_SCRIPT="$BASE_DIR/Multiple_Tomcat_Instances_Startup.sh"
        if [ -f "$START_SCRIPT" ]; then
            echo "$START_SCRIPT" >> "$STATE_FILE"

            # Execute the stop script gracefully
            echo "Stopping service via: $SCRIPT"
            sudo -u egold bash "$SCRIPT"
        fi
    done

    echo "Service stop and state-save completed."

elif [ "$ACTION" == "start" ]; then
    echo "Starting services from saved state..."

    if [ ! -f "$STATE_FILE" ]; then
        echo "No state file found at $STATE_FILE. No services to start."
        exit 0
    fi

    while IFS= read -r START_SCRIPT; do
        if [ -f "$START_SCRIPT" ]; then
            echo "Starting service via: $START_SCRIPT"
            sudo -u egold bash "$START_SCRIPT"
        else
            echo "Warning: Expected start script $START_SCRIPT not found!"
        fi
    done < "$STATE_FILE"

    echo "Service startup completed."

    # Clean up state file
    rm -f "$STATE_FILE"
else
    echo "Invalid action. Use 'stop' or 'start'."
    exit 1
fi
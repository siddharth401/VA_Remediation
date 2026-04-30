#!/bin/bash
# manage_custom_services.sh
# This script discovers, stops, and starts GAIA custom services managed by the `egold` user.

ACTION=$1
STATE_FILE="/tmp/va_remediation_stopped_services.txt"

if [ -z "$ACTION" ]; then
    echo "Usage: $0 {stop|start}"
    exit 1
fi

if [ "$ACTION" == "stop" ]; then
    echo "Starting Auto-Discovery of running GAIA services..."
    > "$STATE_FILE"

    # Locate all GAIA installation directories by finding the 'show_gaia' script
    FOUND_GAIA_SCRIPTS=$(find /opt/GOLD /home/egold -maxdepth 5 -type f -name "show_gaia" 2>/dev/null)

    for SCRIPT in $FOUND_GAIA_SCRIPTS; do
        GAIA_DIR=$(dirname "$SCRIPT")
        echo "Found GAIA directory: $GAIA_DIR"

        # Execute show_gaia from within the directory as egold to find running nodes
        # Expected output format: "GAIA is running on following node(s) :\nCEN510PRD EVT510PRD"
        SHOW_OUTPUT=$(cd "$GAIA_DIR" && sudo -u egold ./show_gaia 2>/dev/null)

        # Parse the output to extract the line after "following node(s) :"
        RUNNING_NODES=$(echo "$SHOW_OUTPUT" | awk '/following node\(s\) :/{getline; print}')

        if [ -n "$RUNNING_NODES" ]; then
            for NODE in $RUNNING_NODES; do
                echo "Discovered active GAIA node: $NODE in $GAIA_DIR"

                # Save state: Format is DIR|NODE
                echo "$GAIA_DIR|$NODE" >> "$STATE_FILE"

                # Stop the node
                echo "Stopping GAIA node $NODE..."
                (cd "$GAIA_DIR" && sudo -u egold ./stop_gaia "$NODE")
            done
        else
            echo "No active nodes found in $GAIA_DIR."
        fi
    done

    echo "GAIA service stop and state-save completed."

elif [ "$ACTION" == "start" ]; then
    echo "Starting GAIA services from saved state..."

    if [ ! -f "$STATE_FILE" ]; then
        echo "No state file found at $STATE_FILE. No services to start."
        exit 0
    fi

    while IFS="|" read -r GAIA_DIR NODE; do
        if [ -n "$GAIA_DIR" ] && [ -n "$NODE" ]; then
            if [ -x "$GAIA_DIR/start_gaia" ]; then
                echo "Starting GAIA node $NODE in $GAIA_DIR..."
                (cd "$GAIA_DIR" && sudo -u egold ./start_gaia "$NODE")
            else
                echo "Warning: start_gaia not found or not executable in $GAIA_DIR!"
            fi
        fi
    done < "$STATE_FILE"

    echo "GAIA service startup completed."

    # Clean up state file
    rm -f "$STATE_FILE"
else
    echo "Invalid action. Use 'stop' or 'start'."
    exit 1
fi
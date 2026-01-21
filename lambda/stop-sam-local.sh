#!/bin/bash

# Script to stop SAM Local running in the background

cd "$(dirname "$0")"

PID_FILE="sam-local.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "SAM Local is not running (no PID file found)"
    exit 0
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping SAM Local (PID: $PID)..."
    kill "$PID"

    # Wait for it to stop (max 10 seconds)
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            echo "✓ SAM Local stopped successfully"
            rm "$PID_FILE"
            exit 0
        fi
        sleep 1
    done

    # Force kill if it didn't stop gracefully
    echo "Force stopping SAM Local..."
    kill -9 "$PID" 2>/dev/null
    rm "$PID_FILE"
    echo "✓ SAM Local stopped (forced)"
else
    echo "SAM Local is not running (stale PID file)"
    rm "$PID_FILE"
fi

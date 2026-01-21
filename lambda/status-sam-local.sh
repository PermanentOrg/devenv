#!/bin/bash

# Script to check SAM Local status

cd "$(dirname "$0")"

PID_FILE="sam-local.pid"
LOG_FILE="sam-local.log"

if [ ! -f "$PID_FILE" ]; then
    echo "SAM Local: NOT RUNNING"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "SAM Local: RUNNING"
    echo "  PID: $PID"
    echo "  Port: 3001"
    echo "  Log file: $LOG_FILE"
    echo ""

    # Check if it's actually listening on the port
    if command -v lsof &> /dev/null; then
        if lsof -i :3001 | grep -q LISTEN; then
            echo "  Status: ✓ Listening on port 3001"
        else
            echo "  Status: ⚠ Process running but not listening on port 3001"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -an | grep -q "3001.*LISTEN"; then
            echo "  Status: ✓ Listening on port 3001"
        else
            echo "  Status: ⚠ Process running but not listening on port 3001"
        fi
    fi

    echo ""
    echo "Recent log entries:"
    echo "---"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "No log file found"

    exit 0
else
    echo "SAM Local: NOT RUNNING (stale PID file)"
    rm "$PID_FILE"
    exit 1
fi

#!/bin/bash

# Script to run SAM Local on the host machine
# This avoids networking issues with containerized SAM Local

cd "$(dirname "$0")"

PID_FILE="sam-local.pid"
LOG_FILE="sam-local.log"

# Parse arguments
DETACH=false
for arg in "$@"; do
    if [ "$arg" = "--detach" ] || [ "$arg" = "-d" ]; then
        DETACH=true
    fi
done

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "SAM Local is already running (PID: $PID)"
        echo "Log file: $LOG_FILE"
        echo ""
        echo "To view logs: tail -f $LOG_FILE"
        echo "To stop: ./stop-sam-local.sh"
        exit 0
    else
        # Stale PID file
        rm "$PID_FILE"
    fi
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "ERROR: AWS SAM CLI is not installed"
    echo ""
    echo "Install it with:"
    echo "  pip install aws-sam-cli"
    echo ""
    echo "Or via Homebrew:"
    echo "  brew install aws-sam-cli"
    exit 1
fi

# Check if the Lambda images exist
MISSING_IMAGES=()
if ! docker images | grep -q "trigger_archivematica_lambda"; then
    MISSING_IMAGES+=("trigger_archivematica_lambda")
fi
if ! docker images | grep -q "record_thumbnail_attacher_lambda"; then
    MISSING_IMAGES+=("record_thumbnail_attacher_lambda")
fi
if ! docker images | grep -q "access_copy_attacher_lambda"; then
    MISSING_IMAGES+=("access_copy_attacher_lambda")
fi
if ! docker images | grep -q "account_space_updater_lambda"; then
    MISSING_IMAGES+=("account_space_updater_lambda")
fi
if ! docker images | grep -q "metadata_attacher_lambda"; then
    MISSING_IMAGES+=("metadata_attacher_lambda")
fi

if [ ${#MISSING_IMAGES[@]} -gt 0 ]; then
    echo "ERROR: Lambda image(s) not found: ${MISSING_IMAGES[*]}"
    echo "Build them first with:"
    echo "  docker compose up -d trigger_archivematica_lambda_builder record_thumbnail_attacher_lambda_builder access_copy_attacher_lambda_builder account_space_updater_lambda_builder metadata_attacher_lambda_builder"
    exit 1
fi

export SAM_CLI_TELEMETRY=0
export SAM_CLI_CONTAINER_CONNECTION_TIMEOUT=60

# Load environment variables from stela .env file
STELA_ENV_FILE="../../stela/.env"
if [ ! -f "$STELA_ENV_FILE" ]; then
    echo "ERROR: Stela .env file not found at $STELA_ENV_FILE"
    exit 1
fi

# Source the .env file to get variables
set -a
source "$STELA_ENV_FILE"
set +a

# Create env vars JSON file for SAM Local
ENV_VARS_FILE="sam-env-vars.json"
cat > "$ENV_VARS_FILE" <<EOF
{
  "TriggerArchivematicaFunction": {
    "DATABASE_URL": "$DATABASE_URL",
    "ARCHIVEMATICA_HOST_URL": "$ARCHIVEMATICA_HOST_URL",
    "ARCHIVEMATICA_API_KEY": "$ARCHIVEMATICA_API_KEY",
    "ARCHIVEMATICA_ORIGINAL_LOCATION_ID": "$ARCHIVEMATICA_ORIGINAL_LOCATION_ID",
    "ARCHIVEMATICA_PROCESSING_WORKFLOW": "$ARCHIVEMATICA_PROCESSING_WORKFLOW",
    "ENV": "$ENV",
    "AWS_REGION": "$AWS_REGION"
  },
  "RecordThumbnailAttacherFunction": {
    "DATABASE_URL": "$DATABASE_URL",
    "ENV": "$ENV",
    "AWS_REGION": "$AWS_REGION",
    "CLOUDFRONT_URL": "$CLOUDFRONT_URL",
    "CLOUDFRONT_KEY_PAIR_ID": "$CLOUDFRONT_KEY_PAIR_ID",
    "CLOUDFRONT_PRIVATE_KEY": "$CLOUDFRONT_PRIVATE_KEY"
  },
  "AccessCopyAttacherFunction": {
    "DATABASE_URL": "$DATABASE_URL",
    "ENV": "$ENV",
    "AWS_REGION": "$AWS_REGION",
    "CLOUDFRONT_URL": "$CLOUDFRONT_URL",
    "CLOUDFRONT_KEY_PAIR_ID": "$CLOUDFRONT_KEY_PAIR_ID",
    "CLOUDFRONT_PRIVATE_KEY": "$CLOUDFRONT_PRIVATE_KEY",
    "S3_BUCKET": "$S3_BUCKET",
    "BACKBLAZE_BUCKET": "$BACKBLAZE_BUCKET"
  },
  "AccountSpaceUpdaterFunction": {
    "DATABASE_URL": "$DATABASE_URL",
    "ENV": "$ENV",
    "AWS_REGION": "$AWS_REGION"
  },
  "AccountSpaceUpdaterFunction": {
    "DATABASE_URL": "$DATABASE_URL",
    "ENV": "$ENV",
    "AWS_REGION": "$AWS_REGION"
  }
}
EOF

if [ "$DETACH" = true ]; then
    echo "Starting SAM Local Lambda endpoint in background..."
    echo "Log file: $LOG_FILE"
    echo ""

    # Start in background
    sam local start-lambda \
        --host 0.0.0.0 \
        --port 3001 \
        --docker-network permanent_default \
        --env-vars "$ENV_VARS_FILE" \
        --template sam_template.yaml \
        > "$LOG_FILE" 2>&1 &

    # Save PID
    echo $! > "$PID_FILE"
    PID=$(cat "$PID_FILE")

    # Wait a moment to see if it starts successfully
    sleep 2

    if ps -p "$PID" > /dev/null 2>&1; then
        echo "✓ SAM Local started successfully (PID: $PID)"
        echo ""
        echo "Useful commands:"
        echo "  View logs:      tail -f $LOG_FILE"
        echo "  Stop SAM Local: ./stop-sam-local.sh"
        echo "  Check status:   ./status-sam-local.sh"
    else
        echo "✗ SAM Local failed to start"
        echo ""
        echo "Check the log file for errors:"
        echo "  cat $LOG_FILE"
        rm "$PID_FILE"
        exit 1
    fi
else
    echo "Starting SAM Local Lambda endpoint..."
    echo "Press Ctrl+C to stop"
    echo ""
    echo "To run in background, use: $0 --detach"
    echo ""

    # Trap Ctrl+C to clean up
    trap 'echo ""; echo "Stopping SAM Local..."; exit 0' INT

    sam local start-lambda \
        --host 0.0.0.0 \
        --port 3001 \
        --docker-network permanent_default \
        --env-vars "$ENV_VARS_FILE" \
        --template sam_template.yaml
fi

# SQS-Lambda Bridge Configuration

This document explains how to configure the SQS-Lambda bridge to connect real or local SQS queues to locally running Lambda functions via SAM Local.

## Overview

The `sqs-lambda-bridge` service polls SQS queues (either LocalStack or real AWS) and invokes Lambda functions running locally via SAM Local. This allows you to develop and test Lambda functions locally while receiving messages from real or local AWS services.

## Architecture

```
AWS SQS Queue → SQS-Lambda Bridge (Docker) → SAM Local (Host) → Lambda Container
```

## Configuration

### 1. Bridge Configuration File

The bridge is configured via `devenv/sqs-lambda-bridge/config.json`. Each bridge entry connects one SQS queue to one Lambda function.

**Example configuration:**

```json
{
  "bridges": [
    {
      "name": "record_thumbnail_attacher",
      "queue": {
        "queueUrl": "https://sqs.us-west-2.amazonaws.com/123456789012/my-queue-name",
        "queueArn": "arn:aws:sqs:us-west-2:123456789012:my-queue-name"
      },
      "lambda": {
        "functionName": "RecordThumbnailAttacherFunction",
        "endpoint": "http://host.docker.internal:3001"
      },
      "batchSize": 10,
      "waitTimeSeconds": 20,
      "visibilityTimeout": 300,
      "deleteOnError": false
    }
  ]
}
```

There is a more complete example in sqs-lambda-bridge/config.example.json; you can copy it to create your sqs-lambda-bridge/config.json,
replacing <DevName> with your first name (capitalized) and <dev_name> with your first name (lowercase).

### 2. Configuration Options

#### Queue Configuration

- **queueUrl** (required): Full URL of the SQS queue
  - For AWS: `https://sqs.{region}.amazonaws.com/{account-id}/{queue-name}`
  - For LocalStack: `http://localstack:4566/000000000000/{queue-name}`
- **queueArn** (optional): ARN of the queue (used in event metadata)
- **endpoint** (optional): Custom endpoint (used for LocalStack, omit for real AWS)

#### Lambda Configuration

- **functionName** (required): Name of the Lambda function as defined in `template.yaml`
- **endpoint** (required for local): SAM Local endpoint URL
  - Use `http://host.docker.internal:3001` when running bridge in Docker

#### Polling Configuration

- **batchSize** (optional): Maximum messages to receive per poll (1-10), default: 10
- **waitTimeSeconds** (optional): Long polling wait time (0-20 seconds), default: 20
- **visibilityTimeout** (optional): Seconds messages are hidden after receipt, default: 300
- **deleteOnError** (optional): Whether to delete messages if Lambda fails, default: false

### 3. Lambda Environment Variables

Define Lambda environment variables in `start-sam-local.sh`. The script generates `sam-env-vars.json` using values loaded from `../stela/.env`.

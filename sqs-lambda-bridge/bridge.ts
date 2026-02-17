#!/usr/bin/env node

/**
 * SQS to Lambda Bridge
 *
 * Polls SQS queues and invokes Lambda functions, supporting both:
 * - LocalStack SQS → SAM Local Lambda
 * - Real AWS SQS → SAM Local Lambda
 * - Real AWS SQS → Real AWS Lambda
 *
 * Configuration via environment variables or config file.
 */

import {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
  DeleteMessageBatchCommand,
  Message,
} from "@aws-sdk/client-sqs";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import fs from "fs";
import path from "path";

interface QueueConfig {
  queueUrl: string;
  queueArn?: string;
  endpoint?: string;
}

interface LambdaConfig {
  functionName: string;
  endpoint?: string;
}

interface BridgeConfig {
  name: string;
  queue: QueueConfig;
  lambda: LambdaConfig;
  batchSize?: number;
  waitTimeSeconds?: number;
  visibilityTimeout?: number;
  deleteOnError?: boolean;
}

interface Config {
  bridges: BridgeConfig[];
}

interface SQSRecord {
  messageId: string;
  receiptHandle: string;
  body: string;
  attributes: Record<string, string>;
  messageAttributes: Record<string, any>;
  md5OfBody: string;
  eventSource: string;
  eventSourceARN: string;
  awsRegion: string;
}

interface SQSEvent {
  Records: SQSRecord[];
}

// Load configuration
function loadConfig(): Config {
  const configPath =
    process.env.BRIDGE_CONFIG || path.join(__dirname, "config.json");

  if (!fs.existsSync(configPath)) {
    console.error(`Configuration file not found: ${configPath}`);
    console.error(
      "Set BRIDGE_CONFIG environment variable or create config.json",
    );
    process.exit(1);
  }

  const configContent = fs.readFileSync(configPath, "utf8");
  const config: Config = JSON.parse(configContent);

  // Validate configuration
  if (!config.bridges || !Array.isArray(config.bridges)) {
    console.error("Configuration must have a 'bridges' array");
    process.exit(1);
  }

  if (config.bridges.length === 0) {
    console.error("Configuration must have at least one bridge");
    process.exit(1);
  }

  // Validate each bridge
  for (const bridge of config.bridges) {
    if (!bridge.name) {
      console.error("Each bridge must have a 'name'");
      process.exit(1);
    }
    if (!bridge.queue?.queueUrl) {
      console.error(`Bridge '${bridge.name}' must have queue.queueUrl`);
      process.exit(1);
    }
    if (!bridge.lambda?.functionName) {
      console.error(`Bridge '${bridge.name}' must have lambda.functionName`);
      process.exit(1);
    }
  }

  return config;
}

// Create SQS client for a queue
function createSQSClient(queueConfig: QueueConfig): SQSClient {
  const config: any = {
    region: process.env.AWS_REGION || "us-west-2",
  };

  // If queue URL contains localhost or localstack, use LocalStack endpoint
  if (
    queueConfig.queueUrl.includes("localhost") ||
    queueConfig.queueUrl.includes("localstack")
  ) {
    config.endpoint = queueConfig.endpoint || "http://localstack:4566";
  }

  return new SQSClient(config);
}

// Create Lambda client for a function
function createLambdaClient(lambdaConfig: LambdaConfig): LambdaClient {
  const config: any = {
    region: process.env.AWS_REGION || "us-west-2",
  };

  // If using SAM Local endpoint
  if (lambdaConfig.endpoint) {
    config.endpoint = lambdaConfig.endpoint;
  }

  return new LambdaClient(config);
}

// Convert SQS Message to SQS Record format
function messageToRecord(
  message: Message,
  queueArn: string,
  region: string,
): SQSRecord {
  return {
    messageId: message.MessageId || "",
    receiptHandle: message.ReceiptHandle || "",
    body: message.Body || "",
    attributes: (message.Attributes as Record<string, string>) || {},
    messageAttributes: message.MessageAttributes || {},
    md5OfBody: message.MD5OfBody || "",
    eventSource: "aws:sqs",
    eventSourceARN: queueArn,
    awsRegion: region,
  };
}

// Process messages from SQS and invoke Lambda
async function processBridge(bridge: BridgeConfig): Promise<never> {
  const sqsClient = createSQSClient(bridge.queue);
  const lambdaClient = createLambdaClient(bridge.lambda);

  const batchSize = bridge.batchSize || 10;
  const waitTimeSeconds = bridge.waitTimeSeconds || 20;
  const visibilityTimeout = bridge.visibilityTimeout || 300;
  const queueArn =
    bridge.queue.queueArn || "arn:aws:sqs:us-west-2:000000000000:unknown";
  const region = process.env.AWS_REGION || "us-west-2";

  console.log(`[${bridge.name}] Starting bridge:`);
  console.log(`  Queue: ${bridge.queue.queueUrl}`);
  console.log(`  Lambda: ${bridge.lambda.functionName}`);
  console.log(`  Batch Size: ${batchSize}`);
  console.log(`  Visibility Timeout: ${visibilityTimeout}s`);

  while (true) {
    try {
      // Poll SQS for messages
      const response = await sqsClient.send(
        new ReceiveMessageCommand({
          QueueUrl: bridge.queue.queueUrl,
          MaxNumberOfMessages: batchSize,
          WaitTimeSeconds: waitTimeSeconds,
          VisibilityTimeout: visibilityTimeout,
          AttributeNames: ["All"],
          MessageAttributeNames: ["All"],
        }),
      );

      const messages = response.Messages;

      if (messages && messages.length > 0) {
        console.log(`[${bridge.name}] Received ${messages.length} message(s)`);

        // Convert messages to SQS event format
        const event: SQSEvent = {
          Records: messages.map((msg) =>
            messageToRecord(msg, queueArn, region),
          ),
        };

        try {
          const invokeResult = await lambdaClient.send(
            new InvokeCommand({
              FunctionName: bridge.lambda.functionName,
              Payload: JSON.stringify(event),
              InvocationType: "RequestResponse",
            }),
          );

          const payloadBytes = invokeResult.Payload;
          const payload = payloadBytes
            ? JSON.parse(new TextDecoder().decode(payloadBytes))
            : null;

          // Check for Lambda errors
          if (invokeResult.FunctionError) {
            console.error(`[${bridge.name}] Lambda invocation error:`, payload);

            // Don't delete messages on Lambda error - they'll become visible again after timeout
            if (bridge.deleteOnError === false) {
              console.log(
                `[${bridge.name}] Messages will be retried (deleteOnError=false)`,
              );
              continue;
            }
          } else {
            console.log(
              `[${bridge.name}] Lambda invoked successfully, processed ${messages.length} message(s)`,
            );
          }

          // Delete successfully processed messages
          if (messages.length === 1) {
            await sqsClient.send(
              new DeleteMessageCommand({
                QueueUrl: bridge.queue.queueUrl,
                ReceiptHandle: messages[0].ReceiptHandle,
              }),
            );
          } else {
            await sqsClient.send(
              new DeleteMessageBatchCommand({
                QueueUrl: bridge.queue.queueUrl,
                Entries: messages.map((msg, idx) => ({
                  Id: String(idx),
                  ReceiptHandle: msg.ReceiptHandle!,
                })),
              }),
            );
          }

          console.log(
            `[${bridge.name}] Deleted ${messages.length} message(s) from queue`,
          );
        } catch (error: any) {
          console.error(
            `[${bridge.name}] Error invoking Lambda:`,
            error.message,
          );

          // Messages will become visible again after visibility timeout for retry
          if (error.message.includes("ECONNREFUSED")) {
            console.error(
              `[${bridge.name}] Lambda endpoint not reachable. Is SAM Local running?`,
            );
          }
        }
      }
    } catch (error: any) {
      console.error(`[${bridge.name}] Error polling SQS:`, error.message);

      // Wait a bit before retrying on error
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
}

// Main
async function main(): Promise<void> {
  console.log("=== SQS to Lambda Bridge ===\n");

  const config = loadConfig();

  console.log(`Loaded configuration with ${config.bridges.length} bridge(s)\n`);

  // Start all bridges in parallel
  const bridgePromises = config.bridges.map((bridge) =>
    processBridge(bridge).catch((error) => {
      console.error(`[${bridge.name}] Fatal error:`, error);
      process.exit(1);
    }),
  );

  await Promise.all(bridgePromises);
}

// Handle graceful shutdown
process.on("SIGINT", () => {
  console.log("\nShutting down gracefully...");
  process.exit(0);
});

process.on("SIGTERM", () => {
  console.log("\nShutting down gracefully...");
  process.exit(0);
});

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

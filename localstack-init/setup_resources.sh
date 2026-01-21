#!/bin/bash
set -e

# Use us-west-2 to match AWS_REGION in stela .env
REGION="us-west-2"

echo "Waiting for LocalStack to be ready..."
awslocal sns list-topics --region $REGION || exit 1

echo "Creating SNS topic: Local_Events$SQS_IDENT in region $REGION"
TOPIC_ARN=$(awslocal sns create-topic --name Local_Events$SQS_IDENT --region $REGION --query 'TopicArn' --output text)
echo "Created topic: $TOPIC_ARN"

echo "Creating SQS queue: Local_Archivematica_Queue$SQS_IDENT"
ARCHIVEMATICA_QUEUE_URL=$(awslocal sqs create-queue --queue-name Local_Archivematica_Queue$SQS_IDENT --region $REGION --query 'QueueUrl' --output text)
ARCHIVEMATICA_QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url $ARCHIVEMATICA_QUEUE_URL --attribute-names QueueArn --region $REGION --query 'Attributes.QueueArn' --output text)
echo "Created queue: $ARCHIVEMATICA_QUEUE_ARN"

echo "Creating SQS queue: Local_Account_Space_Update_Queue$SQS_IDENT"
ACCOUNT_SPACE_QUEUE_URL=$(awslocal sqs create-queue --queue-name Local_Account_Space_Update_Queue$SQS_IDENT --region $REGION --query 'QueueUrl' --output text)
ACCOUNT_SPACE_QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url $ACCOUNT_SPACE_QUEUE_URL --attribute-names QueueArn --region $REGION --query 'Attributes.QueueArn' --output text)
echo "Created queue: $ACCOUNT_SPACE_QUEUE_ARN"

echo "Setting up Archivematica SQS queue policy to allow SNS to send messages"
awslocal sqs set-queue-attributes \
  --queue-url $ARCHIVEMATICA_QUEUE_URL \
  --region $REGION \
  --attributes "{\"Policy\":\"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":\\\"*\\\",\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"$ARCHIVEMATICA_QUEUE_ARN\\\",\\\"Condition\\\":{\\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"$TOPIC_ARN\\\"}}}]}\"}"

echo "Setting up account space SQS queue policy to allow SNS to send messages"
awslocal sqs set-queue-attributes \
  --queue-url $ACCOUNT_SPACE_QUEUE_URL \
  --region $REGION \
  --attributes "{\"Policy\":\"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":\\\"*\\\",\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"$ACCOUNT_SPACE_QUEUE_ARN\\\",\\\"Condition\\\":{\\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"$TOPIC_ARN\\\"}}}]}\"}"

echo "Subscribing Archivematica SQS queue to SNS topic with message filtering"
ARCHIVEMATICA_SUBSCRIPTION_ARN=$(awslocal sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $ARCHIVEMATICA_QUEUE_ARN \
  --region $REGION \
  --attributes "{\"FilterPolicy\":\"{\\\"Entity\\\":[\\\"record\\\"],\\\"Action\\\":[\\\"create\\\",\\\"copy\\\"]}\"}" \
  --query 'SubscriptionArn' \
  --output text)
echo "Created subscription: $ARCHIVEMATICA_SUBSCRIPTION_ARN"

echo "Subscribing Account Space SQS queue to SNS topic with message filtering"
ACCOUNT_SPACE_SUBSCRIPTION_ARN=$(awslocal sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $ACCOUNT_SPACE_QUEUE_ARN \
  --region $REGION \
  --attributes "{\"FilterPolicy\":\"{\\\"Entity\\\":[\\\"record\\\"],\\\"Action\\\":[\\\"create\\\",\\\"copy\\\"]}\"}" \
  --query 'SubscriptionArn' \
  --output text)
echo "Created subscription: $ACCOUNT_SPACE_SUBSCRIPTION_ARN"

echo "LocalStack resources initialized successfully!"
echo "Note: Lambda function is managed by SAM Local (not LocalStack)"
echo "Event processing is handled by the SQS-Lambda bridge service"
echo "Topic ARN: $TOPIC_ARN"
echo "Archivematica Queue ARN: $ARCHIVEMATICA_QUEUE_ARN"
echo "Archivematica Queue URL: $ARCHIVEMATICA_QUEUE_URL"
echo "Account Space Queue ARN: $ACCOUNT_SPACE_QUEUE_ARN"
echo "Account Space Queue URL: $ACCOUNT_SPACE_QUEUE_URL"

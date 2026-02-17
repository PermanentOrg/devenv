# SAM Local Setup

## Prerequisites

[Install the AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)

## View Logs

```bash
# Follow logs in real-time
tail -f lambda/sam-local.log

# View recent logs
tail -50 lambda/sam-local.log

# View all logs
cat lambda/sam-local.log
```

## Development Workflow

### Making Lambda Changes

1. Update Lambda code in `stela`
2. Rebuild Lambda image: `docker compose up -d --build <LAMBDA_BUILDER`
3. Restart SAM Local (`./stop-sam-local.sh` and re-run `./start-sam-local.sh --detach`)
4. Test changes

### Adding a Lambda to the Local Environment

Add your lambda to the [SAM template](sam_template.yaml).

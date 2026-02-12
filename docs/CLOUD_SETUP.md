# Cloud Setup

Permanent's local development environment makes some use of cloud resources in areas that are difficult to replicate locally.
This document describes how to set up the cloud resources necessary for running a local environment.
In the following instructions the string `<dev_name>` should be replaced with the first name of the developer whose local environment is being set up,
all lowercase. `<DevName>` should be replaced with the first name of that developer, Pascal case (i.e. capitalized).

## AWS

Create the following resources via the AWS Console

### SNS

Create an SNS topic called `new-access-copy-topic-local-<dev_name>` with Type = Standard.

### S3

In the `permanent-local` bucket, create a new event notification (these are found in the properties tab).
It should be called `new_dip_file_<dev_name>`, it should filter to the prefix `_<DevName>/access_copies/`,
it should send notifications for all object creation events,
and its destination should be the SNS topic `record-thumbnail-topic-local-<dev_name>`.

### SQS

1. Create three [AWS SQS queues](https://aws.amazon.com/sqs/) (type: Standard) with the following names:
   - `Local_Low_Priority_<DevName>`
   - `Local_Video_<DevName>`
   - `Local_High_Priority_<DevName>`
   - `metadata-attacher-local-<dev_name>`
   - `record-thumbnail-local-<dev_name>`
   - `access-copies-local-<dev_name>`

2. Subscribe the `metadata-attacher`, `record-thumbnail`, and `access-copies` queues to the `record-thumbnail-topic-local-<dev_name>` topic you created earlier.

## Archivematica

1. Open the dev environment's [Archivematica storage service](https://dev.archivematica.permanent.org:8000) (Note: you may need to request access to this from another developer; access is configured in Terraform). Credentials can be found in Bitwarden
2. Navigate to Spaces
3. Under the S3 space pointed at the `permanent-local` bucket, create a new location
4. Set
   - "Purpose" to "Transfer Source"
   - "Relative Path" to `_<DevName>/originals`
   - "Description" to "Original copies (<DevName>'s local env)"
1. Take the id of that location and add it to your stela .env file as `ARCHIVEMATICA_ORIGINAL_LOCATION_ID`
5. Click "Create Location"
6. Repeat steps 3-5, but this time set
   - "Purpose" to "AIP Storage"
   - "Relative Path" to `_<DevName>/preservation_copies`
   - "Description" to "AIP Storage in S3 (<DevName>'s local env)"
7. Repeat steps 3-5, but this time set
   - "Purpose" to "DIP Storage"
   - "Relative Path" to `_<DevName>/access_copies`
   - "Description" to "DIP Storage in S3 (<DevName>'s local env)"
8. Open the dev environment's [Archivematica dashboard](https://dev.archivematica.permanent.org)
9. Under Administration > Processing Configuration, create a new processing configuration called `local_<dev_name>`. Add that to your stela .env file as ARCHIVEMATICA_PROCESSING_WORKFLOW.
10. In your new configuration, copy the values from the `default` configuration, except point the "Store AIP Location" and "Store DIP Location" to the locations created above.

# devenv

This repository contains the configuration information required to
bring up a development environment for the Permanent Legacy Foundation
website.

Note: Many of the shared folders required to bring up the complete
environment are not yet publicly available. This will change. We are
in the process of moving more code into public view, publishing it as
open source, and streamlining our repository structure.

## Usage

1. Prerequisites

   - Access to AWS
   - Install [AWS CLI](https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-install.html)
   - Install [Docker](https://docs.docker.com/get-docker/)
   - Install npm and node (most packages require node 18)
   - Access to Fusionauth OR the values of the env variables that need to be set up for Fusionauth to work.
   - Access to repositories `back-end`, `infrastructure`, `notification-service`, `upload-service`, `web-app`, `stela`

1. Create three [AWS SQS queues](https://aws.amazon.com/sqs/) (type: Standard) with the following names:

   - Local_Low_Priority_YourName
   - Local_Video_YourName
   - Local_High_Priority_YourName

1. Set up directory structure. If you have access to the Permanent repositories, navigate to the parent directory of this directory and clone the needed repositories.

   ```bash
   cd ..
   for r in back-end infrastructure notification-service upload-service web-app stela; do git clone git@github.com:PermanentOrg/$r.git; done
   ```

1. create log folder next to the repo folders. where the backend container's logs folder will be mounted for easy access.

   ```bash
   mkdir log
   ```

1. `cp .env.template .env` and define the required environment variables in `.env` using your preferred file editor.
   You will need to do this for both this repo and the `stela` and `web-app` repos, as they both have the `.env` file referenced in the docker compose file.

   - Create an AWS Access Key [here](https://console.aws.amazon.com/iam/home?#/security_credentials) and download the credentials.
   - Add values for the following variables associated with the key: `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_ACCESS_SECRET`.
   - `SQS_IDENT` will be the name you you selected above when creating the SQS queues, preceded by an underscore.
   - `UPLOAD_SERVICE_SENTRY_DSN` is optional and allows sentry configuration for the upload service.
   - `NOTIFICATION_DATABASE_URL` and `NOTIFICATION_FIREBASE_CREDENTIALS` are required for the notification service

1. Download the SSL certs for the nginx load balancer to use inside the docker network.
   It's important that the AWS env vars have been set for the CLI command to work

   ```
   source .env && aws s3 cp --recursive s3://permanent-local/certs ./certs
   ```

1. Edit your local host file (e.g. `/etc/hosts`) to connect to the host with the correct domain name.

   ```bash
   printf "\n127.0.0.1 local.permanent.org" | sudo tee -a /etc/hosts
   ```

1. Return to `devenv` and run the following command to bring a development environment for the first
   time, or to start up a halted VMs.

   ```bash
   docker-compose up -d
   ```

1. Load the website at https://local.permanent.org/app.

1. When you're done working on the dev environment, bring it down.

   ```bash
   docker-compose down
   ```

## Helpers

#### Repo-Sync Script

---

The repo sync script essentially helps you stay up to date with work going on across the multiple devenv repos.

- Run `./bin/repo-sync.sh` to pull the latest updates from all devenv repos at once.

- Observe the terminal and see what repositories actually recieve updates, this is important to know whether you might need an environment rebuild as in the case of changes in the Infrastructure repository.

- _Usage In Debugging: It's also a good first thing to do if something goes wrong with your environment; as you would need ensure that you are using the latest copy of each repository._

## Troubleshooting
- If the `stela` container claims to be missing dependencies that are stated in the `package.json` file, you may need
to delete your `stela` image and rebuild it. You can find the image with `docker image ls` and delete it with
`docker rmi <image_tag>`, or you can run `docker compose down` followed by `docker system prune --all` to  remove all
images not currently in use. In either case, `docker compose up -d` will rebuild the image.

- If running `docker compose up` results in an error due to port 80 being in use already, you likely need to turn off
  apache, which runs by default on many distros.

- `local.permanent.org/app` redirects the way we're used to, except that `local.permanent.org` gets replaced with the IP
  where the web app is running in the URL. You'll have to change this back to `local.permanent.org` or things won't work
  properly. `local.permanent.org/app/` avoids this. If you are getting a CORS error, then the above redirection could have
  caused it.

- Be sure you're accessing `https://local.permanent.org`, not `http://local.permanent.org`; the latter will not work

## Contributing

Contributors to this repository agree to adhere to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). To report violations, get in touch with engineers@permanent.org.

## Security

Found a vulnerability? Report this and any other security concerns to engineers@permanent.org.

## License

This code is free software licensed as [AGPLv3](LICENSE), or at your
option, any final, later version published by the Free Software
Foundation.

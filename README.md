# devenv

This repository contains the configuration information required to
bring up a development environment for the Permanent Legacy Foundation
website.

Note: Many of the shared folders required to bring up the complete
environment are not yet publicly available.  This will change.  We are
in the process of moving more code into public view, publishing it as
open source, and streamlining our repository structure.

Our current development environment is a VirtualBox VM managed by [Vagrant](https://www.vagrantup.com/).

We use the latest Debian build published [here](https://app.vagrantup.com/generic/boxes/debian10) for our development.

## Usage

1. Install dependencies: [Vagrant](https://www.vagrantup.com/downloads) and [Virtualbox](https://www.virtualbox.org/wiki/Downloads).
```
sudo apt install vagrant
sudo apt install virtualbox
```

2. Install [Virtualbox Guest Additions](https://www.virtualbox.org/manual/ch04.html) to support mounting shared folders.
```
vagrant plugin install vagrant-vbguest
```
If this command fails, check out [Troubleshooting](#troubleshooting) for suggestions.

3. Create three [AWS SQS queues](https://aws.amazon.com/sqs/) (type: Standard) with the following names:
- Local_Low_Priority_YourName
- Local_Video_YourName
- Local_High_Priority_YourName

4. `cp .env.template .env` and define the required environment variables in `.env` using your preferred file editor.
    - Create an AWS Access Key [here](https://console.aws.amazon.com/iam/home?#/security_credentials) and download the credentials.
    - Add values for the following variables associated with the key: `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_ACCESS_SECRET`.
    - `SQS_IDENT` will be the name you you selected above when creating the SQS queues, preceded by an underscore.
    - `DELETE_DATA` removes stateful data if `true` (e.g. S3 files and the contents of the database). This should be `true` for the first `vagrant up`, which runs the provisioner, and can be `true` or `false` for subsequent calls with the `--provision` flag.
    - `UPLOAD_SERVICE_SENTRY_DSN` is optional and allows sentry configuration for the upload service.

 5. Set up directory structure. If you have access to the Permanent repositories, navigate to the parent directory of this directory and clone the needed repositories.
```
cd ..
for r in back-end infrastructure notification-service upload-service web-app; do git clone git@github.com:PermanentOrg/$r.git; done
mkdir log
```

No repository access? Simply create the directories.
```
cd ..
for r in back-end/task-runner back-end/library back-end/api back-end/daemon log; do mkdir -p $r; done
for r in infrastructure upload-service web-app; do git clone git@github.com:PermanentOrg/$r.git; done
```

6. Edit your local host file (e.g. `/etc/hosts`) to connect to the host with the correct domain name.
```
printf "\n192.168.33.10 local.permanent.org" | sudo tee -a /etc/hosts
```

7. Build the front-end.
   ```
   cd ../web-app
   npm install
   cp .env.template .env
   npm run build:local
   ```

   For performance and compatibility reasons, we do not build the static assets
   during vagrant provisioning; instead, the Apache instance inside vagrant
   serves the assets built on the host located in the peer directory
   `web-app/dist`. See the [web-app](https://github.com/PermanentOrg/web-app)
   repo for more information.

8. Run the following command to bring a development environment for the first
time, or to start up a halted VM.
```
source .env && vagrant up
```

Vagrant will only provision your VM on the first run of `vagrant up`. Every subsequent time, you must pass the `--provision` [flag](https://www.vagrantup.com/docs/cli/up#no-provision) to force a provisioner to run. This may be useful to install changes to the development environment, or wipe stateful data with the `DELETE_DATA` environment variable (see step 4 above). For more information about working with vagrant, check out [the docs](https://www.vagrantup.com/docs).

9. Load the website at https://local.permanent.org/app.

10. When you're done working on the dev environment, bring it down.
```
vagrant suspend
```

## Helpers

#### Repo-Sync Script
---

The repo sync script essentially helps you stay up to date with work going on across the multiple devenv repos.

* Run `./bin/repo-sync.sh` to pull the latest updates from all devenv repos at once.

* Observe the terminal and see what repositories actually recieve updates, this is important to know whether you might need an environment rebuild as in the case of changes in the Infrastructure repository.

* *Usage In Debugging: It's also a good first thing to do if something goes wrong with your environment; as you would need ensure that you are using the latest copy of each repository.*

## Troubleshooting

Did you get this error?

```
/sbin/mount.vboxsf: mounting failed with the error: No such device
Vagrant was unable to mount VirtualBox shared folders. This is usually
because the filesystem "vboxsf" is not available. This filesystem is
made available via the VirtualBox Guest Additions and kernel module.
Please verify that these guest additions are properly installed in the
guest. This is not a bug in Vagrant and is usually caused by a faulty
Vagrant box. For context, the command attempted was:

mount -t vboxsf -o uid=1000,gid=1000 data_www_api /data/www/api

The error output from the command was:

/sbin/mount.vboxsf: mounting failed with the error: No such device

```

This likely means that Guest Additions wasn't successfully installed. Try disabling strict dependency checking, and re-installing Virtualbox Guest Additions.

```
export VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1
vagrant plugin install vagrant-vbguest
```

## Contributing

Contributors to this repository agree to adhere to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). To report violations, get in touch with engineers@permanent.org.

## Security

Found a vulnerability? Report this and any other security concerns to engineers@permanent.org.

## License

This code is free software licensed as [AGPLv3](LICENSE), or at your
option, any final, later version published by the Free Software
Foundation.

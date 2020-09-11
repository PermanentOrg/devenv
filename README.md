# devenv

This repository contains the configuration information required to bring up a development environment. Note: Many of the shared folders required to bring up the complete environment are not yet publicly available.

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

4. Create an AWS Access Key. Export the following variables: `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_ACCESS_SECRET`. Here is an example of what that might look like:
```
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="tHiSiSyOuRAcCeSsKeY"
export AWS_ACCESS_SECRET="tHiSiSyOuRAcCeSsSeCrEt"
```

4. Set up directory structure. If you have access to the Permanent repositories, navigate to the parent directory of this directory and clone the needed repositories.
```
cd ..
for r in mdot deploy docker website task-runner library api database files email daemon uploader; do git clone git@bitbucket.org:permanent-org/$r.git; done
mkdir log
mkdir share
echo _YourName > share/sqs.txt
```
Note: For all of the repositories except `website`, you need the default branch checked out. For the `website` repository, you need the `PER-7859-upgrade-wordpress` branch, until the PHP upgrade is complete.

No repository access? Simply create the directories.
```
cd ..
for r in mdot deploy docker website task-runner library api database files email daemon uploader log share; do mkdir $r; done
echo _YourName > share/sqs.txt
```

4. Edit your local host file (e.g. `/etc/hosts`) to connect to the host with the correct domain name.
```
printf "\n192.168.33.10 local.permanent.org" | sudo tee -a /etc/hosts
```

5. Run the following command to bring a development environment for the first time, or to start up a halted VM.
```
vagrant up
```

For more information about working with vagrant, check out [the docs](https://www.vagrantup.com/docs).

6. Load the website at https://local.permanent.org/. If you wish to sign up for an account, do that from the form on https://local.permanent.org/app. It's not possible to create an account locally on https://local.permanent.org/login because this form is an iframe pointing to our production instance.


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

Contributors to this repository agree to adhere to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). To report violations, get in touch with engineering@permanent.org.

## Security

Found a vulnerability? Report this and any other security concerns to engineering@permanent.org.

## License

This code is free software licensed as [AGPLv3](LICENSE). 

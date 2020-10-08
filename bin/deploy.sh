#!/usr/bin/env bash
echo "Running deploy script"
export DEBIAN_FRONTEND=noninteractive
echo "localdev" > /etc/hostname
echo "127.0.0.1 localdev" >> /etc/hosts

echo "Install essential software pacakges"
apt-get -qq update
apt-get -qq install -y git awscli openssl libssl-dev

echo "Configure AWS SQS access"

if [[ "$SQS_IDENT" != _* ]]
	then
	echo "ERROR! Missing or malformed critical environment variables: SQS_IDENT"
	exit 1
fi
if [[ -z "$AWS_REGION" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_ACCESS_SECRET" ]]
    then
	echo "ERROR! Missing critical environment variable: AWS_REGION, AWS_ACCESS_KEY_ID, AWS_ACCESS_SECRET!"
    exit 1
fi

echo $SQS_IDENT > /data/www/sqs.txt
cp -R /var/www/.aws /home/vagrant/
chown -R vagrant /home/vagrant/.aws
chgrp -R vagrant /home/vagrant/.aws

if $DELETE_DATA
then
    echo "Clearing S3 files"
    runuser -l vagrant -c "aws s3 rm s3://permanent-local/$SQS_IDENT --recursive"
fi

echo "Install mysql server and memcache"
apt-get -qq install -y mysql-server memcached

echo "Configure apache"
runuser -l vagrant -c "aws s3 cp --recursive s3://permanent-local/certs /tmp/certs"
mv /tmp/certs/* /etc/ssl
service apache2 stop
# Required for mdot dev server
a2enmod proxy_http
a2enmod ssl
service apache2 start


if $DELETE_DATA
then
    echo "Populate MySQL"
    service mysql restart
    sudo mysql < /data/www/docker/database/perm.sql
    sudo mysql < /data/www/website/database/wp.sql
    sudo mysql wp < /data/www/website/database/dump.sql
fi

echo "Configure uploader"
cd /data/www/uploader
rm -rf node_modules
rm -rf bower_components
# Building the dependencies outside of the shared folder because virtualbox on macOS fails otherwise
runuser -l vagrant -c "cd /data/www/uploader && cp package.json ~ && cp package-lock.json ~"
runuser -l vagrant -c "cd ~ && npm install --no-bin-links"
runuser -l vagrant -c "rm package.json package-lock.json && mv node_modules /data/www/uploader/"
runuser -l vagrant -c "cd /data/www/uploader && bower install"
runuser -l vagrant -c "cd /data/www/uploader && gulp"

echo "Configure PHP application"
cd /data/www/library
rm -rf vendor/
runuser -l vagrant -c "cd /data/www/library && php bin/composer.phar install --no-plugins"

echo "Configure mdot"
cd /data/www/mdot
rm -rf node_modules
rm -rf bower_components
runuser -l vagrant -c "cd /data/www/mdot && cp package.json ~ && cp package-lock.json ~"
runuser -l vagrant -c "cd ~ && npm install --no-bin-links"
runuser -l vagrant -c "rm package.json package-lock.json && mv node_modules /data/www/mdot/"
runuser -l vagrant -c "cd /data/www/mdot && npm rebuild node-sass --no-bin-links"
runuser -l vagrant -c "cd /data/www/mdot && npm run build_local --no-bin-links"

chgrp -R www-data /data/www
ln -s /data/www/api/tests/files /data/tmp/unittest

echo "Install wp-cli"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
runuser -l vagrant -c "curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.4.0/utils/wp-completion.bash && mv wp-completion.bash ~/.bash_completion"

echo "Configure services and cronjobs"
rm /etc/systemd/system/uploader.service
ln -s /data/www/uploader/scripts/uploader.service /etc/systemd/system/
systemctl enable uploader.service

rm /etc/systemd/system/queue-daemon.service
ln -s /data/www/daemon/scripts/queue-daemon.service /etc/systemd/system/
systemctl enable queue-daemon.service

rm /etc/systemd/system/process-daemon.service
ln -s /data/www/daemon/scripts/process-daemon.service /etc/systemd/system/
systemctl enable process-daemon.service

rm /etc/systemd/system/sqs-daemon.service
ln -s /data/www/daemon/scripts/sqs-daemon.service /etc/systemd/system/
systemctl enable sqs-daemon.service

rm /etc/systemd/system/video-daemon.service
ln -s /data/www/daemon/scripts/video-daemon.service /etc/systemd/system/
systemctl enable video-daemon.service

ln -s /data/www/task-runner/scripts/hourly/* /etc/cron.hourly/
ln -s /data/www/task-runner/scripts/monthly/* /etc/cron.monthly/
ln -s /data/www/task-runner/scripts/daily/* /etc/cron.daily/
mkdir /etc/cron.minute
ln -s /data/www/task-runner/scripts/minute/* /etc/cron.minute/

echo -e "* * * * *\troot\tcd / && run-parts --report /etc/cron.minute" >> /etc/crontab

echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "ALL DONE"

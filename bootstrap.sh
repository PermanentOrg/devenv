#!/usr/bin/env bash
echo "Running bootstrap script"
export DEBIAN_FRONTEND=noninteractive
echo "localdev" > /etc/hostname
echo "127.0.0.1 localdev" >> /etc/hosts

echo "US/Central" | sudo tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

echo "Install essential software pacakges"
apt-get -qq update
apt-get -qq install -y curl git htop awscli wget build-essential openssl zip software-properties-common gnupg libssl-dev

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

echo "local" > /data/www/host.txt
echo $SQS_IDENT > /data/www/sqs.txt
runuser -l vagrant -c "cp -R /data/www/devenv/vagrant/home/vagrant/.config /home/vagrant/"
runuser -l vagrant -c "mkdir /home/vagrant/.aws"
envsubst < /data/www/devenv/vagrant/home/vagrant/.aws/credentials > /home/vagrant/.aws/credentials
envsubst < /data/www/devenv/vagrant/home/vagrant/.aws/config > /home/vagrant/.aws/config
if $DELETE_DATA
then
    echo "Clearing S3 files"
    runuser -l vagrant -c "aws s3 rm s3://permanent-local/$SQS_IDENT --recursive"
fi

echo "Add custom sources"
# Add mysql key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5072E1F5
# Add node key
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
# Add custom sources
cp /data/www/devenv/vagrant/etc/apt/sources.list.d/* /etc/apt/sources.list.d/

apt-get -qq update
echo "Install mysql"
apt-get -qq install -y mysql-server mysql-client
echo "Install nodejs"
apt-get -qq install -y nodejs
echo "Install conversion tools"
apt-get -qq install -y libreoffice ffmpeg mediainfo libde265-dev libheif-dev libimage-exiftool-perl
apt-get -qq install -y imagemagick wkhtmltopdf
apt-get -qq install -y apache2 php7.3 libapache2-mod-php php-mysql php-memcache php-memcached memcached php-curl php-cli php-imagick php-gd php-xml php-mbstring php-zip php-igbinary php-msgpack

echo "Configure ImageMagick"
cp /data/www/devenv/vagrant/etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml

echo "Configure apache"
# This is the Apache DocumentRoot, and where the aws php sdk will look for credentials
cp -R /home/vagrant/.aws /var/www
service apache2 stop
a2dissite 000-default
runuser -l vagrant -c "aws s3 cp --recursive s3://permanent-local/certs /tmp/certs"
mv /tmp/certs/* /etc/ssl
cp /data/www/devenv/vagrant/etc/apache2/apache2.conf /etc/apache2/apache2.conf
envsubst < /data/www/devenv/vagrant/etc/apache2/sites-enabled/local.permanent.conf > /etc/apache2/sites-enabled/local.permanent.conf
envsubst < /data/www/devenv/vagrant/etc/apache2/sites-enabled/preload.permanent.conf > /etc/apache2/sites-enabled/preload.permanent.conf
a2enmod ssl
a2enmod expires
a2enmod headers
a2enmod rewrite
a2enmod proxy
a2enconf security
a2enconf charset
a2enconf other-vhosts-access-log
service apache2 start

if $DELETE_DATA
then
    echo "Populate MySQL"
    service mysql restart
    sudo mysql < /data/www/docker/database/perm.sql
    sudo mysql < /data/www/website/database/wp.sql
    sudo mysql wp < /data/www/website/database/dump.sql
fi

echo "Install node global packages"
npm install npm --global
npm install -g gulp
npm install -g bower
npm install -g forever
npm install -g @angular/cli@7.3.6

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
runuser -l vagrant -c "cd /data/www/mdot && cp package.json ~ && cp package-lock.json ~"
runuser -l vagrant -c "cd ~ && npm install --no-bin-links"
runuser -l vagrant -c "rm package.json package-lock.json && mv node_modules /data/www/mdot/"
runuser -l vagrant -c "cd /data/www/mdot && npm rebuild node-sass --no-bin-links"
runuser -l vagrant -c "cd /data/www/mdot && npm run build_local --no-bin-links"

chgrp -R www-data /data/www

mkdir /data/tmp
chmod 777 /data/tmp
ln -s /data/www/api/tests/files /data/tmp/unittest

echo "Install wp-cli"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
runuser -l vagrant -c "curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.4.0/utils/wp-completion.bash && mv wp-completion.bash ~/.bash_completion"

echo "Configure services and cronjobs"
cp /data/www/uploader/scripts/uploader.service /lib/systemd/system/
systemctl enable uploader.service
chmod -x /lib/systemd/system/uploader.service

cp /data/www/daemon/scripts/queue-daemon.service /lib/systemd/system/
systemctl enable queue-daemon.service
chmod -x /lib/systemd/system/queue-daemon.service

cp /data/www/daemon/scripts/process-daemon.service /lib/systemd/system/
systemctl enable process-daemon.service
chmod -x /lib/systemd/system/process-daemon.service

cp /data/www/daemon/scripts/sqs-daemon.service /lib/systemd/system/
systemctl enable sqs-daemon.service
chmod -x /lib/systemd/system/sqs-daemon.service

cp /data/www/daemon/scripts/video-daemon.service /lib/systemd/system/
systemctl enable video-daemon.service
chmod -x /lib/systemd/system/video-daemon.service

chmod +x /data/www/task-runner/scripts/hourly/*
ln -s /data/www/task-runner/scripts/hourly/* /etc/cron.hourly/
chmod +x /data/www/task-runner/scripts/monthly/*
ln -s /data/www/task-runner/scripts/monthly/* /etc/cron.monthly/
chmod +x /data/www/task-runner/scripts/daily/*
ln -s /data/www/task-runner/scripts/daily/* /etc/cron.daily/
chmod +x /data/www/task-runner/scripts/minute/*
mkdir /etc/cron.minute
ln -s /data/www/task-runner/scripts/minute/* /etc/cron.minute/

echo -e "* * * * *\troot\tcd / && run-parts --report /etc/cron.minute" >> /etc/crontab

echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "**********************************************************"
echo "ALL DONE"

#!/usr/bin/env bash
echo "Running configuration script"
export DEBIAN_FRONTEND=noninteractive
TEMPLATES_PATH=/data/www/devenv/templates

echo "US/Central" | sudo tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

echo "Install essential software pacakges"
apt-get -qq update
apt-get -qq install -y curl htop wget build-essential zip software-properties-common gnupg

echo $PERM_ENV  > /data/www/host.txt

echo "Add custom sources"
# Add mysql key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5072E1F5
# Add node key
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
# Add custom sources
cp $TEMPLATES_PATH/etc/apt/sources.list.d/* /etc/apt/sources.list.d/

apt-get -qq update
echo "Install mysql"
apt-get -qq install -y mysql-client
echo "Install nodejs"
apt-get -qq install -y nodejs
echo "Install conversion tools"
apt-get -qq install -y libreoffice ffmpeg mediainfo libde265-dev libheif-dev libimage-exiftool-perl
apt-get -qq install -y imagemagick wkhtmltopdf
apt-get -qq install -y apache2 php7.3 libapache2-mod-php php-mysql php-memcached php-curl php-cli php-imagick php-gd php-xml php-mbstring php-zip php-igbinary php-msgpack

echo "Configure ImageMagick"
cp $TEMPLATES_PATH/etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml

echo "Configure apache"
# This is the Apache DocumentRoot, and where the aws php sdk will look for credentials
mkdir /var/www/.aws
envsubst < $TEMPLATES_PATH/var/www/.aws/credentials > /var/www/.aws/credentials
envsubst < $TEMPLATES_PATH/var/www/.aws/config > /var/www/.aws/config
chgrp www-data /var/www/.aws
chown www-data /var/www/.aws
service apache2 stop
a2dissite 000-default
cp $TEMPLATES_PATH/etc/apache2/apache2.conf /etc/apache2/apache2.conf
envsubst < $TEMPLATES_PATH/etc/apache2/sites-enabled/$PERM_SUBDOMAIN.permanent.conf > /etc/apache2/sites-enabled/$PERM_SUBDOMAIN.permanent.conf
envsubst < $TEMPLATES_PATH/etc/apache2/sites-enabled/preload.permanent.conf > /etc/apache2/sites-enabled/preload.permanent.conf
a2enmod expires
a2enmod headers
a2enmod rewrite
a2enmod proxy
a2enconf security
a2enconf charset
a2enconf other-vhosts-access-log

echo "Install node global packages"
npm install npm --global
npm install -g gulp
npm install -g bower
npm install -g forever
npm install -g @angular/cli@7.3.6

mkdir /data/tmp
chmod 777 /data/tmp

echo "ALL DONE"

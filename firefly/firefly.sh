#!/bin/bash

. $(dirname $0)/firefly_config.sh
. $(dirname $0)/config.sh

# Check which is the latest firefly-iii version
LATEST=$(curl -s 'https://version.firefly-iii.org/index.json' | jq -r .firefly_iii.stable.version)
if [ $LATEST == null ]
then
    LATEST=$(curl -s 'https://version.firefly-iii.org/index.json' | jq -r .firefly_iii.beta.version)
fi
if [ $LATEST == null ]
then
    LATEST=$(curl -s 'https://version.firefly-iii.org/index.json' | jq -r .firefly_iii.alpha.version)
fi

# Config php-fpm
sed -i '' -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.owner = www/listen.owner = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.group = www/listen.group = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;env\[PATH\] /env\[PATH\] /g' /usr/local/etc/php-fpm.d/www.conf

# Install composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Config GitHub api key for composer
composer config -g github-oauth.github.com $GITHUB_API

# Install firefly-iii and csv-importer
cd /usr/local/www && composer create-project grumpydictator/firefly-iii --no-dev --prefer-dist firefly-iii $LATEST

# Configure firefly-iii
sed -i '' -e 's/TRUSTED_PROXIES=.*/TRUSTED_PROXIES=**/g' /usr/local/www/firefly-iii/.env

# Make sure www user has full rights
chown -R www:www /usr/local/www
chmod -R 775 /usr/local/www/firefly-iii/storage

# Enable and start nginx and php_fpm service
sysrc 'nginx_enable=YES' 'php_fpm_enable=YES'
service php-fpm start
service nginx start

# cron job for Firefly III
crontab -u www -l > mycron
echo "0 3 * * * /usr/local/bin/php -f /usr/local/www/firefly-iii/artisan firefly-iii:cron" >> mycron
crontab -u www mycron
rm mycron

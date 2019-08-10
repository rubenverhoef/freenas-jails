#!/bin/bash

. $(dirname $0)/firefly_config.sh
. $(dirname $0)/config.sh

LATEST=$(curl -s https://api.github.com/repos/firefly-iii/firefly-iii/releases/latest | grep "tag_name" | cut -d : -f 2 | tr -d \",)

sed -i '' -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.owner = www/listen.owner = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.group = www/listen.group = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;env\[PATH\] /env\[PATH\] /g' /usr/local/etc/php-fpm.d/www.conf

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
cd /usr/local/www && composer create-project grumpydictator/firefly-iii --no-dev --prefer-dist firefly-iii $LATEST

if [ $LATEST == 4.8.0 ]; then
    sed -i '' -e 's/generate-keys/passport:install/g' /usr/local/www/firefly-iii/app/Console/Commands/Upgrade/UpgradeDatabase.php
fi

sed -i '' -e 's/SITE_OWNER=.*/SITE_OWNER='$EMAIL_ADDRESS'/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/APP_URL=.*/APP_URL=https://'$nextcloud_SUB_DOMAIN'.'$DOMAIN'/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/TRUSTED_PROXIES=.*/TRUSTED_PROXIES=**/g' /usr/local/www/firefly-iii/.env

sed -i '' -e 's/DB_CONNECTION=.*/DB_CONNECTION=mysql/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/DB_HOST=.*/DB_HOST='$webserver_IP'/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/DB_PORT=.*/DB_PORT=3306/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/DB_DATABASE=.*/DB_DATABASE='$firefly_MYSQL_DATABASE'/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/DB_USERNAME=.*/DB_USERNAME='$firefly_MYSQL_USERNAME'/g' /usr/local/www/firefly-iii/.env
sed -i '' -e 's/DB_PASSWORD=.*/DB_PASSWORD='$firefly_MYSQL_PASSWORD'/g' /usr/local/www/firefly-iii/.env

chown -R $USER_NAME:$USER_NAME /usr/local/www

sysrc 'nginx_enable=YES' 'php_fpm_enable=YES'

service php-fpm start
service nginx start

cd /usr/local/www/firefly-iii && php artisan migrate:refresh --seed
cd /usr/local/www/firefly-iii && php artisan firefly-iii:upgrade-database
cd /usr/local/www/firefly-iii && php artisan passport:install

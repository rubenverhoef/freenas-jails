#!/bin/bash

. $(dirname $0)/nextcloud_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

#php configuration
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

sed -i '' -e 's/;date.timezone =/date.timezone = Europe\/Amsterdam/g' /usr/local/etc/php.ini
sed -i '' -e 's/post_max_size = 8M/post_max_size = 0/g' /usr/local/etc/php.ini
sed -i '' -e 's/upload_max_filesize = 2M/upload_max_filesize = 10G/g' /usr/local/etc/php.ini
sed -i '' -e 's/memory_limit = 128M/memory_limit = 512M/g' /usr/local/etc/php.ini
sed -i '' -e 's/;session.upload_progress.enabled/session.upload_progress.enabled /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.enable=1/opcache.enable=1 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.enable_cli=0/opcache.enable_cli=1 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=10000 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.memory_consumption=128/opcache.memory_consumption=128 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.save_comments=1/opcache.save_comments=1 /g' /usr/local/etc/php.ini
sed -i '' -e 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=1 /g' /usr/local/etc/php.ini

sed -i '' -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/user = www/user = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/group = www/group = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.owner = www/listen.owner = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.group = www/listen.group = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;env\[PATH\] /env\[PATH\] /g' /usr/local/etc/php-fpm.d/www.conf

#nextcloud installation:
cd / && fetch "https://download.nextcloud.com/server/releases/latest.tar.bz2"
tar jxf latest.tar.bz2 -C /usr/local/www
rm latest.tar.bz2
if [ "$nextcloud_SUB_DOMAIN" ]; then
	cp $(dirname $0)/nginx.conf /usr/local/etc/nginx/nginx.conf
else
	cp $(dirname $0)/nginx-sub.conf /usr/local/etc/nginx/nginx.conf
fi

cp $(dirname $0)/autoconfig.php /usr/local/www/nextcloud/config/autoconfig.php
sed -i '' -e 's/USERNAME/'$USER_NAME'/g' /usr/local/etc/nginx/nginx.conf
sed -i '' -e 's/WEBSERVER_IP/'$webserver_IP'/g' /usr/local/www/nextcloud/config/autoconfig.php
sed -i '' -e 's/NEXTCLOUD_MYSQL_DATABASE/'$nextcloud_MYSQL_DATABASE'/g' /usr/local/www/nextcloud/config/autoconfig.php
sed -i '' -e 's/NEXTCLOUD_MYSQL_USER/'$nextcloud_MYSQL_USERNAME'/g' /usr/local/www/nextcloud/config/autoconfig.php
sed -i '' -e 's/NEXTCLOUD_MYSQL_PASSWORD/'$nextcloud_MYSQL_PASSWORD'/g' /usr/local/www/nextcloud/config/autoconfig.php

chown -R $USER_NAME:$USER_NAME /usr/local/www

sed -i '' -e 's/port 6379/port 0 /g' /usr/local/etc/redis.conf
sed -i '' -e 's/# unixsocket/unixsocket/g' /usr/local/etc/redis.conf
sed -i '' -e 's/perm 700/perm 777 /g' /usr/local/etc/redis.conf

sysrc 'nginx_enable=YES' 'php_fpm_enable=YES' 'redis_enable=YES'
  
service redis start
service php-fpm start
service nginx start

if [ "$nextcloud_SUB_DOMAIN" ]; then
	curl -s $nextcloud_IP > /dev/null #create config.php
else
	curl -s $nextcloud_IP/nextcloud/ > /dev/null #create config.php
fi

sudo -u $USER_NAME mkdir -p /media/nextcloud/temp
sudo -u $USER_NAME mkdir -p /media/nextcloud/cache
sed -i '' '$ d' /usr/local/www/nextcloud/config/config.php

echo "  'memcache.local' => '\\OC\\Memcache\\Redis'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'memcache.locking' => '\\OC\\Memcache\\Redis'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'redis' => array(" >> "/usr/local/www/nextcloud/config/config.php"
echo "    'host' => '/tmp/redis.sock'," >> "/usr/local/www/nextcloud/config/config.php"
echo "    'port' => 0," >> "/usr/local/www/nextcloud/config/config.php"
echo "  )," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'overwriteprotocol' => 'https'," >> "/usr/local/www/nextcloud/config/config.php"
if [ "$nextcloud_SUB_DOMAIN" ]; then
	echo "  'overwrite.cli.url' => 'https://$nextcloud_SUB_DOMAIN.$DOMAIN'," >> "/usr/local/www/nextcloud/config/config.php"
else
	echo "  'overwritewebroot' => '/nextcloud'," >> "/usr/local/www/nextcloud/config/config.php"
	echo "  'overwrite.cli.url' => 'https://www.$DOMAIN/nextcloud'," >> "/usr/local/www/nextcloud/config/config.php"
fi
echo "  'filesystem_check_changes' => 1," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'skeletondirectory' => ''," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'trashbin_retention_obligation' => 'auto, 2'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'versions_retention_obligation' => 'auto, 2'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'session_lifetime' => 60 * 5," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'enable_previews' => true," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'quota_include_external_storage' => true," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'tempdirectory' => '/media/nextcloud/temp'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'cache_path' => '/media/nextcloud/cache'," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'trusted_domains' => array(" >> "/usr/local/www/nextcloud/config/config.php"
if [ "$nextcloud_SUB_DOMAIN" ]; then
	echo "    0 => '$nextcloud_SUB_DOMAIN.$DOMAIN'," >> "/usr/local/www/nextcloud/config/config.php"
	echo "    1 => 'www.$nextcloud_SUB_DOMAIN.$DOMAIN'," >> "/usr/local/www/nextcloud/config/config.php"
else
	echo "    0 => '$DOMAIN'," >> "/usr/local/www/nextcloud/config/config.php"
	echo "    1 => 'www.$DOMAIN'," >> "/usr/local/www/nextcloud/config/config.php"
fi
echo "  )," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'trusted_proxies' => array(" >> "/usr/local/www/nextcloud/config/config.php"
echo "    '$webserver_IP'" >> "/usr/local/www/nextcloud/config/config.php"
echo "  )," >> "/usr/local/www/nextcloud/config/config.php"
echo "  'forwarded_for_headers' => array(" >> "/usr/local/www/nextcloud/config/config.php"
echo "    'HTTP_X_FORWARDED_FOR'" >> "/usr/local/www/nextcloud/config/config.php"
echo "  )," >> "/usr/local/www/nextcloud/config/config.php"
echo ");" >> "/usr/local/www/nextcloud/config/config.php"

service php-fpm restart
service nginx restart

crontab -u $USER_NAME -l > mycron
echo "*/15 * * * * /usr/local/bin/php -f /usr/local/www/nextcloud/cron.php" >> mycron
echo "*/15 * * * * /usr/local/bin/php -f /usr/local/www/nextcloud/occ preview:pre-generate" >> mycron
crontab -u $USER_NAME mycron
rm mycron

#!/bin/bash

. $(dirname $0)/config.sh
. $(dirname $0)/webserver_config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

BLOWFISH_SECRET="$(openssl rand -base64 32)"
BLOWFISH_SECRET=${BLOWFISH_SECRET//[^[:alnum:]]/}

#php configuration
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

sed -i '' -e 's/;date.timezone =/date.timezone = Europe\/Amsterdam/g' /usr/local/etc/php.ini
sed -i '' -e 's/post_max_size = 8M/post_max_size = 0/g' /usr/local/etc/php.ini
sed -i '' -e 's/upload_max_filesize = 2M/upload_max_filesize = 10G/g' /usr/local/etc/php.ini
sed -i '' -e 's/memory_limit = 128M/memory_limit = 512M/g' /usr/local/etc/php.ini
sed -i '' -e 's/;session.upload_progress.enabled/session.upload_progress.enabled /g' /usr/local/etc/php.ini
 
sed -i '' -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/user = www/user = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/group = www/group = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.owner = www/listen.owner = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.group = www/listen.group = '$USER_NAME'/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;env\[PATH\] /env\[PATH\] /g' /usr/local/etc/php-fpm.d/www.conf

# PHPMyadmin installation
cd /root && fetch "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz" -o phpmyadmin.tar.gz
tar -zxvf phpmyadmin.tar.gz -C /usr/local/www/
mkdir /usr/local/www/phpmyadmin && mv /usr/local/www/phpMyAdmin*/* /usr/local/www/phpmyadmin
rm phpmyadmin.tar.gz && rm -R /usr/local/www/phpMyAdmin*

cp /usr/local/www/phpmyadmin/config.sample.inc.php /usr/local/www/phpmyadmin/config.inc.php
sed -i '' -e 's/\$cfg\['\''blowfish_secret'\''\] = '\'''\'';/\$cfg\['\''blowfish_secret'\''\] = '\'''$BLOWFISH_SECRET\''\'';/g' /usr/local/www/phpmyadmin/config.inc.php

#webserver installation
cp $(dirname $0)/nginx.conf /usr/local/etc/nginx/nginx.conf
sed -i '' -e 's/USERNAME/'$USER_NAME'/g' /usr/local/etc/nginx/nginx.conf
sed -i '' -e 's/DOMAIN_1/www.'$DOMAIN'/g'  /usr/local/etc/nginx/nginx.conf
sed -i '' -e 's/DOMAIN_2/'$DOMAIN'/g'  /usr/local/etc/nginx/nginx.conf
cp $(dirname $0)/letsencrypt.conf /usr/local/etc/nginx/letsencrypt.conf
cp $(dirname $0)/ssl.conf /usr/local/etc/nginx/ssl.conf
cp $(dirname $0)/proxy.conf /usr/local/etc/nginx/proxy.conf
cp $(dirname $0)/standard.conf /usr/local/etc/nginx/standard.conf
mkdir /usr/local/etc/nginx/sites

certbot register -m $EMAIL_ADDRESS --agree-tos --no-eff-email
certbot certonly --standalone -d www.$DOMAIN --keep
certbot certonly --standalone -d $DOMAIN --keep

if [ "$EXTERNAL_GUI" == "YES" ]; then
	bash /root/subdomain.sh freenas $FREENAS_IP $FREENAS_PORT
fi

sysrc 'php_fpm_enable=YES'
sysrc 'nginx_enable=YES' 
sysrc 'mysql_enable=YES'


sed -i '' -e 's/127.0.0.1/0.0.0.0/g' /usr/local/etc/mysql/my.cnf

service mysql-server start
sleep 10

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Would you like to setup VALIDATE PASSWORD plugin?\"
send \"n\r\" 
expect \"Change the password for root ?\"
send \"y\r\"
expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"

mysql -u root -p$MYSQL_ROOT_PASSWORD -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" --connect-expired-password

## Wordpress & Organizr Installation
mkdir /usr/local/organizr
chown $USER_NAME:$USER_NAME /usr/local/organizr
git clone https://github.com/causefx/Organizr /usr/local/www/organizr
if [ "$WORDPRESS_WEB" == "YES" ]; then
	cd /root && fetch "http://wordpress.org/latest.tar.gz" -o wordpress.tar.gz
	tar -zxvf wordpress.tar.gz -C /usr/local/www/
	mv /usr/local/www/wordpress/* /usr/local/www/
	rm wordpress.tar.gz && rm -R /usr/local/www/wordpress

	mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $wordpress_MYSQL_DATABASE;"
	mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $wordpress_MYSQL_DATABASE.* TO '$wordpress_MYSQL_USERNAME'@'%' IDENTIFIED BY '$wordpress_MYSQL_PASSWORD';"
	mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

	cp /usr/local/www/wp-config-sample.php /usr/local/www/wp-config.php
	sed -i '' -e 's/database_name_here/'$wordpress_MYSQL_DATABASE'/g'  /usr/local/www/wp-config.php
	sed -i '' -e 's/username_here/'$wordpress_MYSQL_USERNAME'/g'  /usr/local/www/wp-config.php
	sed -i '' -e 's/password_here/'$wordpress_MYSQL_PASSWORD'/g'  /usr/local/www/wp-config.php
	
	cp $(dirname $0)/config.php /usr/local/www/organizr/config/config.php
	bash /root/subdomain.sh organizr $webserver_IP 8080
	echo "server {" >> /usr/local/etc/nginx/sites/organizr.conf
	echo "	listen 8080;" >> /usr/local/etc/nginx/sites/organizr.conf
	echo "	root /usr/local/www/organizr;" >> /usr/local/etc/nginx/sites/organizr.conf
	echo "	include standard.conf;" >> /usr/local/etc/nginx/sites/organizr.conf
	echo "}" >> /usr/local/etc/nginx/sites/organizr.conf
else
	mv /usr/local/www/organizr/* /usr/local/www
	cp $(dirname $0)/config.php /usr/local/www/config/config.php
fi

chown -R $USER_NAME:$USER_NAME /usr/local/www

service nginx start
service php-fpm start
service mysql-server restart
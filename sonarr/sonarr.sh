#!/bin/bash

. $(dirname $0)/sonarr_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir -p /mnt/media/series
chown -R $USER_NAME:$USER_NAME /mnt/media/series
chown -R $USER_NAME:$USER_NAME /usr/local/share/sonarr/

sysrc 'sonarr_enable=YES'
sysrc 'sonarr_user='$USER_NAME''
service sonarr start
sleep 10
service sonarr stop
if [ -z "$sonarr_SUB_DOMAIN" ]; then
	sed -i '' -e 's,<UrlBase></UrlBase>,<UrlBase>sonarr</UrlBase>,g' /usr/local/sonarr/config.xml
fi
sed -i '' -e 's,<Port>8989</Port>,<Port>'$sonarr_PORT'</Port>,g' /usr/local/sonarr/config.xml

service sonarr start
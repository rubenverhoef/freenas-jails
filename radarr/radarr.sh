#!/bin/bash

. $(dirname $0)/radarr_config.sh
. $(dirname $0)/config.sh

service radarr stop

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

chown -R $USER_NAME:$USER_NAME /usr/local/share/radarr/

sysrc 'radarr_user='$USER_NAME''

rm -rf /usr/local/radarr

service radarr start
sleep 10

if [ -z "$radarr_SUB_DOMAIN" ]; then
	echo "Change URL Base"
	sed -i '' -e 's,<UrlBase></UrlBase>,<UrlBase>radarr</UrlBase>,g' /usr/local/radarr/config.xml
fi
sed -i '' -e 's,<Port>7878</Port>,<Port>'$radarr_PORT'</Port>,g' /usr/local/radarr/config.xml

service radarr restart

#!/bin/bash

. $(dirname $0)/nextcloud_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID

chown -R $USER_NAME:$USER_NAME /srv/homeassistant
chown -R $USER_NAME:$USER_NAME /home/homeassistant/

sysrc 'homeassistant_user='$USER_NAME''
sysrc 'homeassistant_group='$USER_NAME''
service homeassistant restart

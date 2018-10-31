#!/bin/bash

. $(dirname $0)/emby_config.sh
. $(dirname $0)/config.sh

sysrc 'emby_server_enable=YES'
sysrc 'emby_server_user='$USER_NAME''

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

chown -R $USER_NAME:$USER_NAME /var/db/emby*

service emby-server start

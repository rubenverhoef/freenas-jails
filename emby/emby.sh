#!/bin/bash

. $(dirname $0)/emby_config.sh
. $(dirname $0)/config.sh

sysrc 'emby_server_enable=YES'
sysrc 'emby_server_user='$USER_NAME''
sysrc 'emby_server_group='$USER_NAME''
sysrc 'emby_server_data_dir=/var/db/emby-server'

mkdir -p /var/db/emby-server
chown -R $USER_NAME:$USER_NAME /var/db/emby-server

service emby-server start

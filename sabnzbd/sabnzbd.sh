#!/bin/bash

. $(dirname $0)/sabnzbd_config.sh
. $(dirname $0)/config.sh

service sabnzbd stop

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir -p /usr/local/sabnzbd
chown -R $USER_NAME:$USER_NAME /usr/local/sabnzbd
chown -R $USER_NAME:$USER_NAME /var/run/sabnzbd

sysrc 'sabnzbd_user='$USER_NAME''
sysrc 'sabnzbd_group='$USER_NAME''

sed -i '' -e 's,port = 8080,port = '$sabnzbd_PORT',g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,host = 127.0.0.1,host = 0.0.0.0,g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,download_dir = Downloads/incomplete,download_dir = //mnt/downloads/incomplete,g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,complete_dir = Downloads/complete,complete_dir = //mnt/downloads/complete,g' /.sabnzbd/sabnzbd.ini

service sabnzbd start

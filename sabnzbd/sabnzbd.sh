#!/bin/bash

. $(dirname $0)/sabnzbd_config.sh
. $(dirname $0)/config.sh

sed -i '' -e 's,#!/usr/bin/python3*,#!/usr/local/bin/python3.7,g' /root/SABnzbd/SABnzbd.py

sysrc 'sabnzbd_enable=YES'
sysrc 'sabnzbd_user='$USER_NAME''
sysrc 'sabnzbd_group='$USER_NAME''
sysrc 'sabnzbd_conf_dir="/usr/local/sabnzbd"'
sysrc 'sabnzbd_pidfile="/var/run/sabnzbd/sabnzbd.pid"'

rm -rf /usr/local/sabnzbd
mkdir /usr/local/sabnzbd
mkdir /var/run/sabnzbd

chown $USER_NAME:$USER_NAME /usr/local/sabnzbd
chown $USER_NAME:$USER_NAME /var/run/sabnzbd

service sabnzbd start
sleep 10
service sabnzbd stop

sed -i '' -e 's,host = 127.0.0.1,host = 0.0.0.0,g' /usr/local/sabnzbd/sabnzbd.ini
sed -i '' -e 's,download_dir = Downloads/incomplete,download_dir = //mnt/downloads/incomplete,g' /usr/local/sabnzbd/sabnzbd.ini
sed -i '' -e 's,complete_dir = Downloads/complete,complete_dir = //mnt/downloads/complete,g' /usr/local/sabnzbd/sabnzbd.ini

service sabnzbd start

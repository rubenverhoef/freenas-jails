#!/bin/bash

. $(dirname $0)/ombi_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

sysrc 'ombi_enable=YES'
sysrc 'ombi_user='$USER_NAME''
sysrc 'ombi_group='$USER_NAME''
sysrc 'ombi_data_dir="/usr/local/ombi"'
sysrc 'ombi_pidfile="/var/run/ombi/ombi.pid"'

rm -rf /usr/local/ombi
mkdir /usr/local/ombi
mkdir /var/run/ombi

chown $USER_NAME:$USER_NAME /usr/local/ombi
chown $USER_NAME:$USER_NAME /var/run/ombi

service ombi start

#!/bin/bash

. $(dirname $0)/plex_config.sh
. $(dirname $0)/config.sh

service plexmediaserver stop

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir -p /usr/local/plexdata/Plex\ Media\ Server/Mounts/
ln -s /mnt/* /usr/local/plexdata/Plex\ Media\ Server/Mounts/
chown -R $USER_NAME:$USER_NAME /usr/local/plexdata
chown -R $USER_NAME:$USER_NAME /var/run/plex

#sysrc 'ifconfig_epair0_name=epair0b'
sysrc 'plexmediaserver_user=jailuser'
sysrc 'plexmediaserver_group=jailuser'

service plexmediaserver start

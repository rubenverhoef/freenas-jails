#!/bin/bash

. $(dirname $0)/plexpass_config.sh
. $(dirname $0)/config.sh

service plexmediaserver_plexpass stop

pkg install -y ca_root_nss wget perl5.28

ln -s /usr/local/bin/perl5.28.0 /usr/local/bin/perl

sh $(dirname $0)/PMS_Updater.sh -u $PLEX_USER -p $PLEX_PASS -a

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir -p /usr/local/plexdata-plexpass/Plex\ Media\ Server/Mounts/
ln -s /mnt/* /usr/local/plexdata-plexpass/Plex\ Media\ Server/Mounts/
chown -R $USER_NAME:$USER_NAME /usr/local/plexdata-plexpass
chown -R $USER_NAME:$USER_NAME /var/run/plex

#sysrc 'ifconfig_epair0_name=epair0b'
sysrc 'plexmediaserver_plexpass_user='$USER_NAME''
sysrc 'plexmediaserver_plexpass_group='$USER_NAME''

service plexmediaserver_plexpass start

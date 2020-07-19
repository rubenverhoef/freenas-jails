#!/bin/bash

. $(dirname $0)/plex_config.sh
. $(dirname $0)/config.sh

service plexmediaserver stop

ln -s /usr/local/bin/perl5.30.0 /usr/local/bin/perl

if [ $PLEX_USER ]; then
    sh $(dirname $0)/PMS_Updater.sh -u $PLEX_USER -p$PLEX_PASS -a
else
    sh $(dirname $0)/PMS_Updater.sh -n -a
fi

mkdir -p /usr/local/plexdata/Plex\ Media\ Server/Mounts/
ln -s /mnt/* /usr/local/plexdata/Plex\ Media\ Server/Mounts/
chown -R $USER_NAME:$USER_NAME /usr/local/plexdata
chown -R $USER_NAME:$USER_NAME /var/run/plex

#sysrc 'ifconfig_epair0_name=epair0b'
sysrc 'plexmediaserver_user='$USER_NAME''
sysrc 'plexmediaserver_group='$USER_NAME''
sysrc 'plexmediaserver_support_path=/usr/local/plexdata'

service plexmediaserver restart

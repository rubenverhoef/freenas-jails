#!/bin/bash

. $(dirname $0)/plex_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

sysrc 'ifconfig_epair0_name=epair0b'
sysrc 'plexmediaserver_enable=YES'
sysrc 'plexmediaserver_user='$USER_NAME''
sysrc 'plexmediaserver_group='$USER_NAME''

#!/bin/bash

. $(dirname $0)/plexpass_config.sh
. $(dirname $0)/config.sh

mkdir -p /usr/local/etc/pkg/repos
echo "FreeBSD: {" >> "/usr/local/etc/pkg/repos/FreeBSD.conf"
echo "    url: \"pkg+http://pkg.FreeBSD.org/\${ABI}/latest\"" >> "/usr/local/etc/pkg/repos/FreeBSD.conf"
echo "}" >> "/usr/local/etc/pkg/repos/FreeBSD.conf"

pkg update -f
pkg upgrade -y

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir -p /usr/local/plexdata-plexpass/Plex\ Media\ Server/Mounts/
ln -s /mnt/* /usr/local/plexdata-plexpass/Plex\ Media\ Server/Mounts/
chown -R $USER_NAME:$USER_NAME /usr/local/plexdata-plexpass

sysrc 'ifconfig_epair0_name=epair0b'
sysrc 'plexmediaserver_plexpass_enable=YES'
sysrc 'plexmediaserver_plexpass_user='$USER_NAME''
sysrc 'plexmediaserver_plexpass_group='$USER_NAME''

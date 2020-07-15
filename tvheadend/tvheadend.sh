#!/bin/bash

. $(dirname $0)/tvheadend_config.sh
. $(dirname $0)/config.sh

service tvheadend stop

sysrc 'tvheadend_user='$USER_NAME''
sysrc 'tvheadend_group='$USER_NAME''

chown -R $USER_NAME:$USER_NAME /usr/local/etc/tvheadend
chown -R $USER_NAME:$USER_NAME /var/log/tvheadend

service tvheadend start

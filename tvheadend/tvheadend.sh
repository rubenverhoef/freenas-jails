#!/bin/bash

. $(dirname $0)/tvheadend_config.sh
. $(dirname $0)/config.sh

service tvheadend stop

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

sysrc 'tvheadend_user='$USER_NAME''
sysrc 'tvheadend_group='$USER_NAME''

service tvheadend start

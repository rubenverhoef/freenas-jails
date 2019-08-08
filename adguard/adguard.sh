#!/bin/bash

. $(dirname $0)/adguard_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

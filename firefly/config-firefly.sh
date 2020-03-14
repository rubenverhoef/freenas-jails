#!/bin/bash

. $(dirname $0)/firefly_config.sh
. $(dirname $0)/../config.sh

iocage set -P firefly-iii=SITE_OWNER=$EMAIL_ADDRESS
iocage set -P firefly-iii=APP_URL=$firefly_SUB_DOMAIN.$DOMAIN
iocage set -P firefly-iii=DB_CONNECTION=mysql
iocage set -P firefly-iii=DB_HOST=$webserver_IP
iocage set -P firefly-iii=DB_PORT=3306
iocage set -P firefly-iii=DB_DATABASE=$firefly_MYSQL_DATABASE
iocage set -P firefly-iii=DB_USERNAME=$firefly_MYSQL_USERNAME
iocage set -P firefly-iii=DB_PASSWORD=$firefly_MYSQL_PASSWORD

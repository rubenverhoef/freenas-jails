#!/bin/bash

. $(dirname $0)/firefly_config.sh
. $(dirname $0)/../config.sh

iocage set -P firefly-iii=SITE_OWNER=$EMAIL_ADDRESS firefly
iocage set -P firefly-iii=APP_URL=$firefly_SUB_DOMAIN.$DOMAIN firefly
iocage set -P firefly-iii=DB_CONNECTION=mysql firefly
iocage set -P firefly-iii=DB_HOST=$webserver_IP firefly
iocage set -P firefly-iii=DB_PORT=3306 firefly
iocage set -P firefly-iii=DB_DATABASE=$firefly_MYSQL_DATABASE firefly
iocage set -P firefly-iii=DB_USERNAME=$firefly_MYSQL_USERNAME firefly
iocage set -P firefly-iii=DB_PASSWORD=$firefly_MYSQL_PASSWORD firefly

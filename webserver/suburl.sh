#!/bin/bash

. $(dirname $0)/config.sh

rm /usr/local/etc/nginx/sites/$1.conf
sed -i '' -e '/.*'$1'.*/d' /usr/local/etc/nginx/standard.conf
echo "location /$1 { include proxy.conf; proxy_pass http://$2:$3; }" >> "/usr/local/etc/nginx/standard.conf"

service nginx restart

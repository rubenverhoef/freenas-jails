#!/bin/bash

. $(dirname $0)/dsmr_config.sh
. $(dirname $0)/config.sh

sed -i '' -e 's,#!/bin/bash*,#!/usr/local/bin/bash,g' /home/dsmr/dsmr-reader/post-deploy.sh
ln -s /usr/local/bin/python3.7 /usr/local/bin/python3

#!/bin/bash

. $(dirname $0)/sabnzbd_config.sh
. $(dirname $0)/config.sh

#create user
pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin

mkdir /.sabnzbd
chown $USER_NAME:$USER_NAME /.sabnzbd

python2.7 -m pip install cheetah
python2.7 -m pip install cryptography
python2.7 -m pip install sabyenc

cd / && curl -s https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest | grep "browser_download_url.*-src.tar.gz" | cut -d : -f 2,3 | tr -d \" | wget -qi -
tar -xvzf SABnzbd*.tar.gz -C /root
rm SABnzbd*.tar.gz
mv /root/SABnzbd* /root/SABnzbd

cp $(dirname $0)/sabnzbd /etc/rc.d/sabnzbd
chmod +x /etc/rc.d/sabnzbd

ln -s /usr/local/bin/python2.7 /usr/bin/python

sysrc 'sabnzbd_enable=YES'
sysrc 'sabnzbd_user='$USER_NAME''
sysrc 'sabnzbd_group='$USER_NAME''

service sabnzbd start
sleep 10
service sabnzbd stop

sed -i '' -e 's,port = 8080,port = '$sabnzbd_PORT',g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,host = 127.0.0.1,host = 0.0.0.0,g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,download_dir = Downloads/incomplete,download_dir = //mnt/downloads/incomplete,g' /.sabnzbd/sabnzbd.ini
sed -i '' -e 's,complete_dir = Downloads/complete,complete_dir = //mnt/downloads/complete,g' /.sabnzbd/sabnzbd.ini

service sabnzbd start
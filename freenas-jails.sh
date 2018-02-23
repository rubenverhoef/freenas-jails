#!/bin/bash

#DEFAULT VALUES:
{
DEFAULT_DOMAIN="example.com"
DEFAULT_ROUTER="192.168.0.1"
DEFAULT_JAIL_LOCATION="/mnt/iocage/jails"
DEFAULT_BACKUP_LOCATION="/mnt/data/backup_jails"
DEFAULT_EMAIL_ADDRESS="admin@example.com"

webserver_DEFAULT_IP="192.168.0.12"
webserver_DEFAULT_MAC="d2:f0:5b:49:91:cb"
wordpress_DEFAULT_USERNAME="wordpress_user"
wordpress_DEFAULT_DATABASE="wordpress"

nextcloud_DEFAULT_IP="192.168.0.13"
nextcloud_DEFAULT_PORT="80"
nextcloud_DEFAULT_MAC="4a:66:71:10:f7:ad"
nextcloud_DEFAULT_USERNAME="nextcloud_user"
nextcloud_DEFAULT_DATABASE="nextcloud"

sabnzbd_DEFAULT_IP="192.168.0.14"
sabnzbd_DEFAULT_PORT="8080"
sabnzbd_DEFAULT_MAC="02:ff:30:00:09:0b"

sonarr_DEFAULT_IP="192.168.0.15"
sonarr_DEFAULT_PORT="8989"
sonarr_DEFAULT_MAC="6e:24:27:3f:70:c2"

radarr_DEFAULT_IP="192.168.0.16"
radarr_DEFAULT_PORT="7878"
radarr_DEFAULT_MAC="92:15:2c:7e:8c:1b"

ombi_DEFAULT_IP="192.168.0.17"
ombi_DEFAULT_PORT="8989"
ombi_DEFAULT_MAC=""

plex_DEFAULT_IP="192.168.0.18"
plex_DEFAULT_PORT="32400"
plex_DEFAULT_MAC=""

emby_DEFAULT_IP="192.168.0.19"
emby_DEFAULT_PORT="8989"
emby_DEFAULT_MAC=""

gogs_DEFAULT_IP="192.168.0.20"
gogs_DEFAULT_PORT="8989"
gogs_DEFAULT_MAC=""

homeassistant_DEFAULT_IP="192.168.0.30"
homeassistant_DEFAULT_PORT="8989"
homeassistant_DEFAULT_MAC=""
}

first () {

	exec 3>&1
	CHOICE=$(dialog --menu "What would you like to do:" 0 0 0 \
	"Install jails" "Choose what software/jail you want to install" \
	"Upgrade jail" "Upgrade a specific jail" \
	"Mount storage" "Mount storage to a jail" \
	"Backup jail" "Backup a specific jail" \
	"Delete jail" "Delete a specific jail" \
	"Delete config" "Delete a specific jail" \
	2>&1 1>&3)
	exec 3>&-

	if [ "$?" = "0" ]
	then
		# Install is selected
		if [ "$CHOICE" = "Install jails" ]
		then
			install_dialog
		fi
		
		# Upgrdae is selected
		if [ "$CHOICE" = "Upgrade jail" ]
		then
			upgrade_jail
		fi
		
		# Backup is selected
		if [ "$CHOICE" = "Backup jail" ]
		then
			backup_jail
		fi
		
		# Delete is selected
		if [ "$CHOICE" = "Delete jail" ]
		then
			delete_jail
		fi
		
		# Delete config is selected
		if [ "$CHOICE" = "Delete config" ]
		then
			delete_config
		fi
		if [ "$CHOICE" = "Mount storage" ]
		then
			mount_storage
		fi
	fi
}

install_dialog () {
	
	if ! grep -q "JAIL_LOCATION" "$(dirname $0)/config.sh"; then
		echo -e "JAIL_LOCATION=\"$DEFAULT_JAIL_LOCATION\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "BACKUP_LOCATION" "$(dirname $0)/config.sh"; then
		echo -e "\nBACKUP_LOCATION=\"$DEFAULT_BACKUP_LOCATION\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "USER_NAME" "$(dirname $0)/config.sh"; then
		echo -e "\nUSER_NAME=\"\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "USER_ID" "$(dirname $0)/config.sh"; then
		echo -e "\nUSER_ID=\"\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "ROUTER_IP" "$(dirname $0)/config.sh"; then
		echo -e "\nROUTER_IP=\"$DEFAULT_ROUTER\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	
	#load updated config file
	. $(dirname $0)/config.sh
	
	exec 3>&1
	JAIL=$(dialog --form "IOCAGE Jail location:" 0 0 0 \
	"Jail location (starting with \"/\" and without last \"/\")" 1 1 "$JAIL_LOCATION" 1 60 25 0 \
	"Backup location (starting with \"/\" and without last \"/\")" 2 1 "$BACKUP_LOCATION" 2 60 25 0 \
	"Please create a USER in the FreeNAS WebGUI!!" 3 1 "" 3 60 0 0 \
	"User name:" 4 1 "$USER_NAME" 4 60 25 0 \
	"User ID (UID):" 5 1 "$USER_ID" 5 60 25 0 \
	"Router (DHCP server) IP:" 7 1 "$ROUTER_IP" 7 60 15 0 \
	2>&1 1>&3)
	exec 3>&-
	
	info_arr=( $JAIL )
	sed -i '' -e 's,JAIL_LOCATION="'$JAIL_LOCATION'",JAIL_LOCATION="'${info_arr[0]}'",g' $(dirname $0)/config.sh
	sed -i '' -e 's,BACKUP_LOCATION="'$BACKUP_LOCATION'",BACKUP_LOCATION="'${info_arr[1]}'",g' $(dirname $0)/config.sh
	sed -i '' -e 's,USER_NAME="'$USER_NAME'",USER_NAME="'${info_arr[2]}'",g' $(dirname $0)/config.sh
	sed -i '' -e 's,USER_ID="'$USER_ID'",USER_ID="'${info_arr[3]}'",g' $(dirname $0)/config.sh
	sed -i '' -e 's,ROUTER_IP="'$ROUTER_IP'",ROUTER_IP="'${info_arr[4]}'",g' $(dirname $0)/config.sh
	
	exec 3>&1
	JAILS=$(dialog --separate-output --checklist "Install following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" 1 \
	Nextcloud "Nextcloud 12" 1 \
	SABnzbd "SABnzbd" 1 \
	Sonarr "Sonarr automatic serice downloader" 1 \
	Radarr "Radarr automatic movie downloader" 1 \
	Ombi "Your personal media assistant!" 1 \
	Plex "Plex Media Server" 1 \
	Emby "The open media solution" 1 \
	Gogs "Go Git  Server" 1 \
	HomeAssistant "Home-Assistant (Python 3)" 1 \
	2>&1 1>&3)
	exec 3>&-
	
	if [ "$?" = "0" ]
	then
		jail_arr=( $JAILS )
		if [ -n "$jail_arr" ]; then
			for i in $(seq 1 ${#jail_arr[@]})
			do	
				config_jail ${jail_arr[$i-1],,}
				install_jail ${jail_arr[$i-1],,}
			done
		fi
	fi
	first
}

config_jail () {

	JAIL_NAME=$1\_JAIL_NAME
	SUB_DOMAIN=$1\_SUB_DOMAIN
	DEFAULT_IP=$1\_DEFAULT_IP
	DEFAULT_PORT=$1\_DEFAULT_PORT
	DEFAULT_MAC=$1\_DEFAULT_MAC
	IP=$1\_IP
	PORT=$1\_PORT
	MAC=$1\_MAC

	mkdir -p $(dirname $0)/$1
	touch  $(dirname $0)/$1/$1_config.sh || exit
	
	if ! grep -q "$JAIL_NAME" "$(dirname $0)/$1/$1_config.sh"; then
		echo -e "\n$JAIL_NAME=\"${1,,}_1\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if [[ $1 == *"webserver"* ]]; then
		if ! grep -q "DOMAIN" "$(dirname $0)/config.sh"; then
			echo -e "DOMAIN=\"$DEFAULT_DOMAIN\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
		fi
		if ! grep -q "$IP" "$(dirname $0)/config.sh"; then
			echo -e "$IP=\"${!DEFAULT_IP}\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
		fi
	else
		if ! grep -q "$SUB_DOMAIN" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "$SUB_DOMAIN=\"\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi
	fi
	if ! grep -q "$IP" "$(dirname $0)/$1/$1_config.sh"; then
		echo -e "$IP=\"${!DEFAULT_IP}\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "$PORT" "$(dirname $0)/$1/$1_config.sh"; then
		echo -e "$PORT=\"${!DEFAULT_PORT}\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "$MAC" "$(dirname $0)/$1/$1_config.sh"; then
		echo -e "$MAC=\"${!DEFAULT_MAC}\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
	fi	
	
	#load updated config file
	. $(dirname $0)/$1/$1_config.sh
	. $(dirname $0)/config.sh
	
	exec 3>&1
	if [[ $1 == "webserver" ]]; then
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Jail name:" 1 1 "${!JAIL_NAME}" 1 40 25 0 \
		"IP address:" 2 1 "${!IP}" 2 40 15 0 \
		"MAC address:" 3 1 "${!MAC}" 3 40 17 0 \
		"Domain name (without https://www.)" 4 1 "$DOMAIN" 4 40 25 0 \
		2>&1 1>&3)
	else
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Jail name:" 1 1 "${!JAIL_NAME}" 1 30 25 0 \
		"IP address:" 2 1 "${!IP}" 2 30 15 0 \
		"MAC address:" 3 1 "${!MAC}" 3 30 17 0 \
		"Application PORT:" 4 1 "${!PORT}" 4 30 5 0 \
		"Keep emtpy for no Subdomain" 5 1 "" 5 30 0 0 \
		"Subdomain name" 6 1 "${!SUB_DOMAIN}" 6 30 25 0 \
		2>&1 1>&3)
	fi
	exec 3>&-
	
	array=( $VALUES )
	if [[ $1 == "webserver" ]]; then
		sed -i '' -e 's/DOMAIN="'$DOMAIN'"/DOMAIN="'${array[3]}'"/g' $(dirname $0)/config.sh
	else
		sed -i '' -e 's/'$SUB_DOMAIN'="'${!SUB_DOMAIN}'"/'$SUB_DOMAIN'="'${array[4]}'"/g' $(dirname $0)/$1/$1_config.sh
	fi
	
	sed -i '' -e 's/'$JAIL_NAME'="'${!JAIL_NAME}'"/'$JAIL_NAME'="'${array[0]}'"/g' $(dirname $0)/$1/$1_config.sh
	if [[ $1 == "webserver" ]]; then
		sed -i '' -e 's/'$IP'="'${!IP}'"/'$IP'="'${array[1]}'"/g' $(dirname $0)/config.sh
	fi
	sed -i '' -e 's/'$IP'="'${!IP}'"/'$IP'="'${array[1]}'"/g' $(dirname $0)/$1/$1_config.sh
	sed -i '' -e 's/'$MAC'="'${!MAC}'"/'$MAC'="'${array[2]}'"/g' $(dirname $0)/$1/$1_config.sh
	sed -i '' -e 's/'$PORT'="'${!PORT}'"/'$PORT'="'${array[3]}'"/g' $(dirname $0)/$1/$1_config.sh

	if [[ $1 == "webserver" ]]; then
		if ! grep -q "EMAIL_ADDRESS" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "EMAIL_ADDRESS=\"$DEFAULT_EMAIL_ADDRESS\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi
		if ! grep -q "MYSQL_ROOT_PASSWORD" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "MYSQL_ROOT_PASSWORD=\"\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi
		if ! grep -q "SUB_DOMAIN" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "SUB_DOMAIN=\"organizr\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi	
		if ! grep -q "EXTERNAL_GUI" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "EXTERNAL_GUI=\"NO\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi			
		if ! grep -q "WORDPRESS_WEB" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "WORDPRESS_WEB=\"NO\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi			
		if ! grep -q "FREENAS_IP" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "FREENAS_IP=\"\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi	
		if ! grep -q "FREENAS_PORT" "$(dirname $0)/$1/$1_config.sh"; then
			echo -e "FREENAS_PORT=\"\"" >> "$(dirname $0)/$1/$1_config.sh" | tr '[:upper:]' '[:lower:]'
		fi	

		#load updated config file
		. $(dirname $0)/$1/$1_config.sh

		dialog --title "External access" --yesno "Do you want to make the FreeNAS webGUI accessible from outside your network?" 7 60
		if [ "$?" = "0" ]; then
			sed -i '' -e 's/EXTERNAL_GUI="NO"/EXTERNAL_GUI="YES"/g' $(dirname $0)/$1/$1_config.sh
			exec 3>&1
			FREENASIP=$(dialog --form "Webserver configuration:" 0 0 0 \
			"FreeNAS webGUI IP:" 1 1 "$FREENAS_IP" 1 30 25 0 \
			"FreeNAS webGUI Port:" 2 2 "$FREENAS_PORT" 2 30 5 0 \
			2>&1 1>&3)
			exec 3>&-
			FREENASARR=( $FREENASIP )
			sed -i '' -e 's/FREENAS_IP="'$FREENAS_IP'"/FREENAS_IP="'${FREENASARR[0]}'"/g' $(dirname $0)/$1/$1_config.sh
			sed -i '' -e 's/FREENAS_PORT="'$FREENAS_PORT'"/FREENAS_PORT="'${FREENASARR[1]}'"/g' $(dirname $0)/$1/$1_config.sh
		else
			sed -i '' -e 's/EXTERNAL_GUI="YES"/EXTERNAL_GUI="NO"/g' $(dirname $0)/$1/$1_config.sh
		fi
			
		exec 3>&1
		VALUE=$(dialog --form "Webserver configuration:" 0 0 0 \
		"Email address:" 1 1 "$EMAIL_ADDRESS" 1 30 25 0 \
		2>&1 1>&3)
		exec 3>&-

		sed -i '' -e 's/EMAIL_ADDRESS="'$EMAIL_ADDRESS'"/EMAIL_ADDRESS="'$VALUE'"/g' $(dirname $0)/$1/$1_config.sh

		exec 3>&1
		PASS=$(dialog --title "Setting Password:" \
		--clear \
		--insecure \
		--passwordbox "Set MySQL Root password:" 0 0 "$MYSQL_ROOT_PASSWORD" \
		2>&1 1>&3)
		exec 3>&-

		sed -i '' -e 's/MYSQL_ROOT_PASSWORD="'$MYSQL_ROOT_PASSWORD'"/MYSQL_ROOT_PASSWORD="'$PASS'"/g' $(dirname $0)/$1/$1_config.sh
		
		dialog --title "Hosting WordPress Website?" --yesno "Do you want to host a WordPress website?" 7 60
		if [ "$?" = "0" ]; then
			sed -i '' -e 's/WORDPRESS_WEB="NO"/WORDPRESS_WEB="YES"/g' $(dirname $0)/$1/$1_config.sh
			exec 3>&1
			VALUE1=$(dialog --form "Organizr subdomain:" 0 0 0 \
			"Organizr subdomain:" 1 1 "$SUB_DOMAIN" 1 30 25 0 \
			2>&1 1>&3)
			exec 3>&-
			sed -i '' -e 's/'SUB_DOMAIN'="'$SUB_DOMAIN'"/'SUB_DOMAIN'="'$VALUE1'"/g' $(dirname $0)/$1/$1_config.sh
			config_mysql "wordpress" "webserver"
		else
			sed -i '' -e 's/WORDPRESS_WEB="YES"/WORDPRESS_WEB="NO"/g' $(dirname $0)/$1/$1_config.sh
		fi
	fi
	
	if [[ $1 == "nextcloud" ]]; then
		config_mysql "nextcloud" "nextcloud"
	fi
}

config_mysql () {
	MYSQL_USER=$1\_MYSQL_USERNAME
	MYSQL_DATA=$1\_MYSQL_DATABASE
	MYSQL_PASS=$1\_MYSQL_PASSWORD
	DEFAULT_USER=$1\_DEFAULT_USERNAME
	DEFAULT_DATA=$1\_DEFAULT_DATABASE
	
	if ! grep -q "$MYSQL_USER" "$(dirname $0)/$2/$2_config.sh"; then
		echo -e "$MYSQL_USER=\"${!DEFAULT_USER}\"" >> "$(dirname $0)/$2/$2_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "$MYSQL_DATA" "$(dirname $0)/$2/$2_config.sh"; then
		echo -e "$MYSQL_DATA=\"${!DEFAULT_DATA}\"" >> "$(dirname $0)/$2/$2_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "$MYSQL_PASS" "$(dirname $0)/$2/$2_config.sh"; then
		echo -e "$MYSQL_PASS=\"\"" >> "$(dirname $0)/$2/$2_config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	
	#load updated config file
	. $(dirname $0)/$2/$2_config.sh
	
	exec 3>&1
	VALUES=$(dialog --form "Webserver configuration:" 0 0 0 \
	"$1 MySQL User:" 1 1 "${!MYSQL_USER}" 1 30 25 0 \
	"$1 MySQL Database:" 2 1 "${!MYSQL_DATA}" 2 30 25 0 \
	2>&1 1>&3)
	exec 3>&-
	
	array=( $VALUES )
	sed -i '' -e 's/'$MYSQL_USER'="'${!MYSQL_USER}'"/'$MYSQL_USER'="'${array[0]}'"/g' $(dirname $0)/$2/$2_config.sh
	sed -i '' -e 's/'$MYSQL_DATA'="'${!MYSQL_DATA}'"/'$MYSQL_DATA'="'${array[1]}'"/g' $(dirname $0)/$2/$2_config.sh

	exec 3>&1
	PASS=$(dialog --title "Setting Password:" \
	--clear \
	--insecure \
	--passwordbox "Set MySQL $1 password:" 0 0 "${!MYSQL_PASS}" \
	2>&1 1>&3)
	exec 3>&-

	sed -i '' -e 's/'$MYSQL_PASS'="'${!MYSQL_PASS}'"/'$MYSQL_PASS'="'$PASS'"/g' $(dirname $0)/$2/$2_config.sh
}

install_jail () {

	. $(dirname $0)/$1/$1_config.sh
	. $(dirname $0)/config.sh
	JAIL_NAME=$1\_JAIL_NAME
	MAC=$1\_MAC
	IP=$1\_IP
	PORT=$1\_PORT
	SUB_DOMAIN=$1\_SUB_DOMAIN
	
	VERSION="$(uname -r)"
	VERSION=${VERSION//[!0-9,.]/}-RELEASE

	if [[ $(iocage list) != *${!JAIL_NAME}* ]]; then
		
		iocage create -n ${!JAIL_NAME} -p $(dirname $0)/$1/$1.json -r $VERSION ip4_addr="vnet0|${!IP}/24" defaultrouter="$ROUTER_IP" vnet="on" allow_raw_sockets="1" boot="on"
		
		mount_storage $1
		
		cp $(dirname $0)/$1/* $JAIL_LOCATION/${!JAIL_NAME}/root/root/
		cp $(dirname $0)/config.sh $JAIL_LOCATION/${!JAIL_NAME}/root/root/
		
		iocage exec ${!JAIL_NAME} bash /root/$1.sh
		#monit (monitoring, auto backup, auto update (not upgrade..)?)
		if [[ $1 != "webserver" ]]; then  #configure subdomain
			. $(dirname $0)/webserver/webserver_config.sh
			if [ -z "${!SUB_DOMAIN}" ]; then
				iocage exec $webserver_JAIL_NAME bash /root/suburl.sh $1 ${!IP} ${!PORT}
			else
				iocage exec $webserver_JAIL_NAME bash /root/subdomain.sh ${!SUB_DOMAIN} ${!IP} ${!PORT}
			fi
		fi
		if [[ $1 == "nextcloud" ]] || [[ $1 == "gogs" ]]; then  #configure mysql
			DATABASE=$1\_MYSQL_DATABASE
			USER=$1\_MYSQL_USERNAME
			PASS=$1\_MYSQL_PASSWORD
			iocage exec $webserver_JAIL_NAME bash /root/mysql.sh ${!DATABASE} ${!USER} ${!PASS}
		fi
		#create mysql user (and database) for gogs
		#look for backup and ask to restore?
		if [ -d "$BACKUP_LOCATION/$1" ]; then
			dialog --title "Restore backup?" --yesno "Do you want to restore the backup?\"?" 7 60
			i=$?
			if [ "$i" = "0" ]; then
				cp -R $BACKUP_LOCATION/$1$(<$(dirname $0)/$1/backup.conf)/ $JAIL_LOCATION/${!JAIL_NAME}/root$(<$(dirname $0)/$1/backup.conf)
				chown -R $USER_NAME:$USER_NAME $JAIL_LOCATION/${!JAIL_NAME}/root$(<$(dirname $0)/$1/backup.conf)
				iocage restart ${!JAIL_NAME}
			fi
		fi
		dialog --msgbox "$1 installed" 0 0
	else
		dialog --msgbox "$1 already installed, use the upgrade function in main menu!" 0 0
	fi

}

mount_storage () {
	
	JAIL=$1
	
	if [[ $1 == "" ]]; then
		JAIL=$(dialog -menu "Mount storage to:" 0 0 0 \
		Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" 1 \
		Nextcloud "Nextcloud 12" 1 \
		SABnzbd "SABnzbd" 1 \
		Sonarr "Sonarr automatic serice downloader" 1 \
		Radarr "Radarr automatic movie downloader" 1 \
		Ombi "Your personal media assistant!" 1 \
		Plex "Plex Media Server" 1 \
		Emby "The open media solution" 1 \
		Gogs "Go Git  Server" 1 \
		HomeAssistant "Home-Assistant (Python 3)" 1 \
		2>&1 1>&3)
		exec 3>&-
		JAIL=${JAIL,,} 
	fi
	
	echo $JAIL
	. $(dirname $0)/$JAIL/$JAIL\_config.sh
	. $(dirname $0)/config.sh
	JAIL_NAME=$JAIL\_JAIL_NAME
	
	if [[ $JAIL == "nextcloud" ]]; then
		DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose a folder for the use of user data on $JAIL" --fselect /mnt/ 14 48)
		chown -R $USER_NAME:$USER_NAME $DATA
		iocage fstab -a ${!JAIL_NAME} $DATA /media nullfs rw 0 0
	fi
	if [[ $JAIL == "sonarr" ]] || [[ $JAIL == "radarr" ]] || [[ $JAIL == "sabnzbd" ]] || [[ $JAIL == "plex" ]] || [[ $JAIL == "emby" ]] || [[ $JAIL == "ombi" ]]; then
		DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose the media folder for $JAIL" --fselect /mnt/ 14 48)
		chown -R $USER_NAME:$USER_NAME $DATA
		iocage fstab -a ${!JAIL_NAME} $DATA /mnt/media nullfs rw 0 0
		DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose the download folder for $JAIL" --fselect /mnt/ 14 48)
		chown -R $USER_NAME:$USER_NAME $DATA
		iocage fstab -a ${!JAIL_NAME} $DATA /mnt/downloads nullfs rw 0 0
	fi

	
	i="0"
	while [ "$i" = "0" ]; do
	{
		dialog --title "Mount more storage to $JAIL?" --yesno "Do you want to mount more storage to $JAIL?\"?" 7 60
		i=$?
		if [ "$i" = "0" ]; then
			DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose a folder to mount at /mnt on $JAIL" --fselect /mnt/ 14 48)
			chown -R $USER_NAME:$USER_NAME $DATA
			iocage fstab -a ${!JAIL_NAME} $DATA /mnt/$(basename $DATA) nullfs rw 0 0
		fi		
	}
	done
}

delete_jail () {
	exec 3>&1
	JAILS=$(dialog --separate-output --checklist "Delete following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" 1 \
	Nextcloud "Nextcloud 12" 1 \
	SABnzbd "SABnzbd" 1 \
	Sonarr "Sonarr automatic serice downloader" 1 \
	Radarr "Radarr automatic movie downloader" 1 \
	Ombi "Your personal media assistant!" 1 \
	Plex "Plex Media Server" 1 \
	Emby "The open media solution" 1 \
	Gogs "Go Git  Server" 1 \
	HomeAssistant "Home-Assistant (Python 3)" 1 \
	2>&1 1>&3)
	exec 3>&-
	
	if [ "$?" = "0" ]
	then
		jail_arr=( $JAILS )
		if [ -n "$jail_arr" ]; then
			for i in $(seq 1 ${#jail_arr[@]})
			do	
				. $(dirname $0)/${jail_arr[$i-1],,}/${jail_arr[$i-1],,}_config.sh
				. $(dirname $0)/webserver/webserver_config.sh
				. $(dirname $0)/config.sh
				JAIL_NAME=${jail_arr[$i-1],,}\_JAIL_NAME
				dialog --title "Delete Program/Jail" \
				--yesno "Are you sure you want to permanently delete ${!JAIL_NAME}?" 7 60
				if [ "$?" = "0" ]; then
					iocage stop ${!JAIL_NAME}
					iocage destroy ${!JAIL_NAME} -f
					iocage destroy ${!JAIL_NAME} -f
					dialog --title "Delete backup" \
					--yesno "Do you want to delete the backup of ${!JAIL_NAME} also?" 7 60
					if [ "$?" = "0" ]; then
						rm -R $BACKUP_LOCATION/${jail_arr[$i-1],,}
					fi
					rm $JAIL_LOCATION/$webserver_JAIL_NAME/root/usr/local/etc/nginx/sites/${jail_arr[$i-1],,}.conf
					sed -i '' -e '/.*'${jail_arr[$i-1],,}'.*/d' $JAIL_LOCATION/$webserver_JAIL_NAME/root/usr/local/etc/nginx/standard.conf
					if [[ ${jail_arr[$i-1],,} == *"nextcloud"* ]]; then
						DATABASE=${jail_arr[$i-1],,}\_MYSQL_DATABASE
						iocage exec $webserver_JAIL_NAME mysql -u root -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS ${!DATABASE};"
					fi
					dialog --msgbox "${!JAIL_NAME} deleted" 5 30 #not looking good..
				else
					dialog --msgbox "${!JAIL_NAME} NOT deleted, operation canceled by user!" 5 30 #not looking good..
				fi
			done
		fi
	fi
	first
}

delete_config () { #delete backup, delete config not helpfull...
	exec 3>&1
	JAILS=$(dialog --separate-output --checklist "Delete config files of following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" 1 \
	Nextcloud "Nextcloud 12" 1 \
	SABnzbd "SABnzbd" 1 \
	Sonarr "Sonarr automatic serice downloader" 1 \
	Radarr "Radarr automatic movie downloader" 1 \
	Ombi "Your personal media assistant!" 1 \
	Plex "Plex Media Server" 1 \
	Emby "The open media solution" 1 \
	Gogs "Go Git  Server" 1 \
	HomeAssistant "Home-Assistant (Python 3)" 1 \
	2>&1 1>&3)
	exec 3>&-
	
	if [ "$?" = "0" ]
	then
		jail_arr=( $JAILS )
		if [ -n "$jail_arr" ]; then
			for i in $(seq 1 ${#jail_arr[@]})
			do	
				. $(dirname $0)/${jail_arr[$i-1],,}/${jail_arr[$i-1],,}_config.sh
				JAIL_NAME=${jail_arr[$i-1],,}\_JAIL_NAME
				dialog --title "Delete config" \
				--yesno "Are you sure you want to permanently delete the config files of ${!JAIL_NAME}\"?" 7 60
				if [ "$?" = "0" ]; then
					rm $(dirname $0)/${jail_arr[$i-1],,}/${jail_arr[$i-1],,}_config.sh
					dialog --msgbox "Config files of ${!JAIL_NAME} deleted" 5 30 #not looking good..
				else
					dialog --msgbox "Config files of ${!JAIL_NAME} NOT deleted, operation canceled by user!" 5 30 #not looking good..
				fi
			done
		fi
	fi

	first
}

backup_jail () {
	if ! grep -q "JAIL_LOCATION" "$(dirname $0)/config.sh"; then
		echo -e "JAIL_LOCATION=\"$DEFAULT_JAIL_LOCATION\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	if ! grep -q "BACKUP_LOCATION" "$(dirname $0)/config.sh"; then
		echo -e "\nBACKUP_LOCATION=\"$DEFAULT_BACKUP_LOCATION\"" >> "$(dirname $0)/config.sh" | tr '[:upper:]' '[:lower:]'
	fi
	
	#load updated config file
	. $(dirname $0)/config.sh
	
	exec 3>&1
	JAIL=$(dialog --form "IOCAGE Jail location:" 0 0 0 \
	"Jail location (starting with \"/\" and without last \"/\")" 1 1 "$JAIL_LOCATION" 1 60 25 0 \
	"Backup location (starting with \"/\" and without last \"/\")" 2 1 "$BACKUP_LOCATION" 2 60 25 0 \
	2>&1 1>&3)
	exec 3>&-
	
	info_arr=( $JAIL )
	sed -i '' -e 's,JAIL_LOCATION="'$JAIL_LOCATION'",JAIL_LOCATION="'${info_arr[0]}'",g' $(dirname $0)/config.sh
	sed -i '' -e 's,BACKUP_LOCATION="'$BACKUP_LOCATION'",BACKUP_LOCATION="'${info_arr[1]}'",g' $(dirname $0)/config.sh
	mkdir -p $BACKUP_LOCATION
	
	exec 3>&1
	JAILS=$(dialog --separate-output --checklist "Backup following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" 1 \
	Nextcloud "Nextcloud 12" 1 \
	SABnzbd "SABnzbd" 1 \
	Sonarr "Sonarr automatic serice downloader" 1 \
	Radarr "Radarr automatic movie downloader" 1 \
	Ombi "Your personal media assistant!" 1 \
	Plex "Plex Media Server" 1 \
	Emby "The open media solution" 1 \
	Gogs "Go Git  Server" 1 \
	HomeAssistant "Home-Assistant (Python 3)" 1 \
	2>&1 1>&3)
	exec 3>&-
	
	#load updated config file
	. $(dirname $0)/config.sh
	
	if [ "$?" = "0" ]
	then
		jail_arr=( $JAILS )
		if [ -n "$jail_arr" ]; then
			for i in $(seq 1 ${#jail_arr[@]})
			do	
				. $(dirname $0)/${jail_arr[$i-1],,}/${jail_arr[$i-1],,}_config.sh
				JAIL_NAME=${jail_arr[$i-1],,}\_JAIL_NAME
				mkdir -p $BACKUP_LOCATION/${jail_arr[$i-1],,}
				#$JAIL_LOCATION/${!JAIL_NAME}/root/%
				iocage stop ${!JAIL_NAME}
				mkdir -p $BACKUP_LOCATION/${jail_arr[$i-1],,}$(<$(dirname $0)/${jail_arr[$i-1],,}/backup.conf)
				cp -R $JAIL_LOCATION/${!JAIL_NAME}/root$(<$(dirname $0)/${jail_arr[$i-1],,}/backup.conf)/ $BACKUP_LOCATION/${jail_arr[$i-1],,}$(<$(dirname $0)/${jail_arr[$i-1],,}/backup.conf)
				#cat $(dirname $0)/${jail_arr[$i-1],,}/backup.conf | xargs -J % cp -R /mnt/iocage/jails/sonarr_1/root/% $BACKUP_LOCATION/${jail_arr[$i-1],,}
				iocage start ${!JAIL_NAME}
				dialog --msgbox "Config of ${!JAIL_NAME} backuped!" 5 50
			done
		fi
	fi
	#make mysql dump?
	first
}

upgrade_jail () {
	dialog --msgbox "Not implemented yet!" 5 30
	first
}

touch $(dirname $0)/config.sh || exit
. $(dirname $0)/config.sh

first
#!/bin/bash

# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

# Globals:
INTERFACE="$(ifconfig | head -n1 | sed -e 's/:.*$//')"
LOCAL_IP="$(ifconfig $INTERFACE | grep 'inet' -m 1 | cut -d' ' -f2)"
LOCAL_IP_LSV="$(echo $LOCAL_IP | cut -d. -f4)"
BASE_IP="$(echo $LOCAL_IP | cut -d. -f1-3)"
ROUTER_IP="$(netstat -rn | grep 'default' -m 1 | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
IOCAGE_SHARED_IP=$BASE_IP.$((LOCAL_IP_LSV + 2))
GLOBAL_CONFIG=$(dirname $0)"/config.sh"
DATABASE_JAILS="webserver, nextcloud, gogs, firefly"
MEDIA_JAILS=(plex emby sonarr radarr sabnzbd tvheadend)
FILE_JAILS=(nextcloud)
CUSTOM_PLUGIN=(tvheadend plex emby sabnzbd radarr sonarr webserver nextcloud adguard firefly dsmr)
VNET_PLUGIN=(tvheadend plex webserver dsmr)
CHANGEABLE_PORT=(sonarr radarr sabnzbd)

# DEFAULT VALUES:
DEFAULT_DOMAIN="example.com"
DEFAULT_IOCAGE_ZPOOL="ssd"
DEFAULT_JAIL_LOCATION="/mnt/iocage/jails"
DEFAULT_BACKUP_LOCATION="/mnt/data/backup_jails"
DEFAULT_EMAIL_ADDRESS="admin@example.com"

webserver_DEFAULT_IP=$BASE_IP.$((LOCAL_IP_LSV + 1))
webserver_DEFAULT_USERNAME="wordpress_user"
webserver_DEFAULT_DATABASE="wordpress"

plex_DEFAULT_IP=$BASE_IP.$((LOCAL_IP_LSV + 3))
plex_DEFAULT_PORT="32400"
emby_DEFAULT_PORT="8096"
sabnzbd_DEFAULT_PORT="8080"
sonarr_DEFAULT_PORT="8989"
radarr_DEFAULT_PORT="7878"
tvheadend_DEFAULT_PORT="9981"
tvheadend_DEFAULT_IP=$BASE_IP.$((LOCAL_IP_LSV + 5))
nextcloud_DEFAULT_PORT="80"
nextcloud_DEFAULT_USERNAME="nextcloud_user"
nextcloud_DEFAULT_DATABASE="nextcloud"
adguard_DEFAULT_PORT="3000"
firefly_DEFAULT_PORT="8000"
firefly_DEFAULT_USERNAME="firefly_user"
firefly_DEFAULT_DATABASE="firefly"
dsmr_DEFAULT_PORT="8100"

first () {

	exec 3>&1
	CHOICE=$(dialog --menu "What would you like to do:" 0 0 0 \
	"Install jails" "Choose what software/jail you want to install" \
	"Upgrade jail" "Upgrade a specific jail" \
	"Mount storage" "Mount storage to a jail" \
	"Backup jail" "Backup a specific jail" \
	"Delete jail" "Delete a specific jail" \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		exit
	fi
	
	case $CHOICE in
		"Install jails")
			install_dialog
			;;
		
		"Upgrade jail")
			upgrade_jail
			;;
		
		"Backup jail")
			backup_jail
			;;
			
		"Delete jail")
			delete_jail
			;;
		
		"Mount storage")
			mount_storage
			;;
	esac
}

install_dialog () {
	
	if  [[ $1 == "" ]]; then
		# initialize file with variables if they don't exists
		if ! grep -q "JAIL_LOCATION" $GLOBAL_CONFIG; then
			echo -e "JAIL_LOCATION=\""$DEFAULT_JAIL_LOCATION"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "IOCAGE_ZPOOL" $GLOBAL_CONFIG; then
			echo -e "IOCAGE_ZPOOL=\""$DEFAULT_IOCAGE_ZPOOL"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "IOCAGE_SHARED_IP" $GLOBAL_CONFIG; then
			echo -e "IOCAGE_SHARED_IP=\""$IOCAGE_SHARED_IP"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "BACKUP_LOCATION" $GLOBAL_CONFIG; then
			echo -e "BACKUP_LOCATION=\""$DEFAULT_BACKUP_LOCATION"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "USER_NAME" $GLOBAL_CONFIG; then
			echo -e "USER_NAME=\"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "USER_ID" $GLOBAL_CONFIG; then
			echo -e "USER_ID=\"\"" >> $GLOBAL_CONFIG
		fi
		
		# load updated config file
		. $GLOBAL_CONFIG
		
		exec 3>&1
		JAIL=$(dialog --form "IOCAGE Jail location:" 0 0 0 \
		"Iocage ZPOOL" 1 1 "$IOCAGE_ZPOOL" 1 60 25 0 \
		"Iocage Shared IP" 2 1 "$IOCAGE_SHARED_IP" 2 60 15 0 \
		"Backup location (starting with \"/\" and without last \"/\")" 3 1 "$BACKUP_LOCATION" 3 60 25 0 \
		"Please create a USER in the FreeNAS WebGUI!!" 4 1 "" 4 60 0 0 \
		"User name:" 5 1 "$USER_NAME" 5 60 25 0 \
		"User ID (UID):" 6 1 "$USER_ID" 6 60 25 0 \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			first
		fi
		
		GLOBAL=( $JAIL )
		
		#save new config variables in global config file
		sed -i '' -e 's,IOCAGE_ZPOOL="'$IOCAGE_ZPOOL'",IOCAGE_ZPOOL="'${GLOBAL[0]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,IOCAGE_SHARED_IP="'$IOCAGE_SHARED_IP'",IOCAGE_SHARED_IP="'${GLOBAL[1]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,BACKUP_LOCATION="'$BACKUP_LOCATION'",BACKUP_LOCATION="'${GLOBAL[2]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,USER_NAME="'$USER_NAME'",USER_NAME="'${GLOBAL[3]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,USER_ID="'$USER_ID'",USER_ID="'${GLOBAL[4]}'",g' $GLOBAL_CONFIG
    fi
	
	exec 3>&1
	PROGRAM=$(dialog --menu "Install following program:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
	Nextcloud "Nextcloud 12" \
	SABnzbd "SABnzbd" \
	Sonarr "Sonarr automatic serice downloader" \
	Radarr "Radarr automatic movie downloader" \
	Plex "Plex Media Server" \
	Emby "Emby Media Server" \
	Tvheadend "Tvheadend TV streaming server" \
	AdGuard "DNS Adblocker"\
	FireFly "Personal finances manager"\
	DSMR "DSMR Reader"\
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		first
	fi
	
	config_jail ${PROGRAM,,}
	install_jail ${PROGRAM,,}

	install_dialog second_time #back to install_dialog but without config dialog
}

config_jail () {
	JAIL=$1
	SUB_DOMAIN=$1\_SUB_DOMAIN
	DEFAULT_IP=$JAIL\_DEFAULT_IP
	DEFAULT_PORT=$JAIL\_DEFAULT_PORT
	IP=$JAIL\_IP
	PORT=$JAIL\_PORT
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"

    # make directory and file if not exists already
	mkdir -p ${JAIL_CONFIG%/*}/
	touch  $JAIL_CONFIG || exit
	
    # initialize file with variables if they don't exists
	if [[ $JAIL == *"webserver"* ]]; then
		if ! grep -q "DOMAIN" $GLOBAL_CONFIG; then
			echo -e "DOMAIN=\""$DEFAULT_DOMAIN"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q $IP $GLOBAL_CONFIG; then
			echo -e $IP"=\""${!DEFAULT_IP}"\"" >> $GLOBAL_CONFIG
		fi
	else
		if ! grep -q $SUB_DOMAIN $JAIL_CONFIG; then
			echo -e $SUB_DOMAIN"=\"\"" >> $JAIL_CONFIG
		fi
		if ! grep -q $PORT $JAIL_CONFIG; then
			echo -e $PORT"=\""${!DEFAULT_PORT}"\"" >> $JAIL_CONFIG
		fi
	fi
	if ! grep -q $IP $JAIL_CONFIG; then
		echo -e $IP"=\""${!DEFAULT_IP}"\"" >> $JAIL_CONFIG
	fi
	if [[ $JAIL == "plex" ]]; then
		if ! grep -q "PLEX_USER" $JAIL_CONFIG; then
			echo -e "PLEX_USER=\""$PLEX_USER"\"" >> $JAIL_CONFIG
		fi
		if ! grep -q "PLEX_PASS" $JAIL_CONFIG; then
			echo -e "PLEX_PASS=\""$PLEX_PASS"\"" >> $JAIL_CONFIG
		fi
	fi
	
	# load updated config files
	. $JAIL_CONFIG
	. $GLOBAL_CONFIG
	
	exec 3>&1
	if [[ $JAIL == "webserver" ]]; then
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"IP address:" 1 1 "${!IP}" 1 40 15 0 \
		"Domain name (without https://www.)" 2 1 "$DOMAIN" 2 40 25 0 \
		2>&1 1>&3)
	elif [[ $JAIL == "plex" ]]; then
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"IP address:" 1 1 "${!IP}" 1 30 15 0 \
			"Application PORT:" 2 1 "${!PORT}" 2 30 5 0 \
			"Keep emtpy for no Subdomain" 3 1 "" 3 30 0 0 \
			"Subdomain name" 4 1 "${!SUB_DOMAIN}" 4 30 25 0 \
			"Blank for normal plex" 5 1 "" 5 30 0 0 \
			"Plex.tv username" 6 1 "$PLEX_USER" 6 30 25 0 \
			2>&1 1>&3)
		else
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"IP address:" 1 1 "${!IP}" 1 30 15 0 \
			"Keep emtpy for no Subdomain" 2 1 "" 2 30 0 0 \
			"Subdomain name" 3 1 "${!SUB_DOMAIN}" 3 30 25 0 \
			"Blank for normal plex" 4 1 "" 4 30 0 0 \
			"Plex.tv username" 5 1 "$PLEX_USER" 5 30 25 0 \
			2>&1 1>&3)
		fi
	elif [[ ${VNET_PLUGIN[*]} == *$JAIL* ]]; then
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"IP address:" 1 1 "${!IP}" 1 30 15 0 \
			"Application PORT:" 2 1 "${!PORT}" 2 30 5 0 \
			"Keep emtpy for no Subdomain" 3 1 "" 3 30 0 0 \
			"Subdomain name" 4 1 "${!SUB_DOMAIN}" 4 30 25 0 \
			2>&1 1>&3)
		else
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"IP address:" 1 1 "${!IP}" 1 30 15 0 \
			"Keep emtpy for no Subdomain" 2 1 "" 2 30 0 0 \
			"Subdomain name" 3 1 "${!SUB_DOMAIN}" 3 30 25 0 \
			2>&1 1>&3)
		fi
	else
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"Application PORT:" 1 1 "${!PORT}" 1 30 5 0 \
			"Keep emtpy for no Subdomain" 2 1 "" 2 30 0 0 \
			"Subdomain name" 3 1 "${!SUB_DOMAIN}" 3 30 25 0 \
			2>&1 1>&3)
		else
			VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
			"Keep emtpy for no Subdomain" 1 1 "" 1 30 0 0 \
			"Subdomain name" 2 1 "${!SUB_DOMAIN}" 2 30 25 0 \
			2>&1 1>&3)
		fi
	fi
	exit_status=$?
	exec 3>&-

	if [ $exit_status != $DIALOG_OK ]; then
		install_dialog second_time
	fi

    # save new variables in jail config file
	JAIL_VALUES=( $VALUES )

	if [[ $JAIL == "webserver" ]]; then
		sed -i '' -e 's,'$IP'="'${!IP}'",'$IP'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		sed -i '' -e 's,'$IP'="'${!IP}'",'$IP'="'${JAIL_VALUES[0]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,DOMAIN="'$DOMAIN'",DOMAIN="'${JAIL_VALUES[1]}'",g' $GLOBAL_CONFIG
	elif [[ $JAIL == "plex" ]]; then
		sed -i '' -e 's,'$IP'="'${!IP}'",'$IP'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			sed -i '' -e 's,'$PORT'="'${!PORT}'",'$PORT'="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[2]}'",g' $JAIL_CONFIG
			sed -i '' -e 's,PLEX_USER="'$PLEX_USER'",PLEX_USER="'${JAIL_VALUES[3]}'",g' $JAIL_CONFIG
		else	
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
			sed -i '' -e 's,PLEX_USER="'$PLEX_USER'",PLEX_USER="'${JAIL_VALUES[2]}'",g' $JAIL_CONFIG
		fi
		exec 3>&1
		PASS=$(dialog --title "PlexPass Password:" \
		--clear \
		--insecure \
		--passwordbox "Plex.tv PlexPass password:" 0 0 "$PLEX_PASS" \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			install_dialog second_time
		fi
		sed -i '' -e 's,PLEX_PASS="'$PLEX_PASS'",PLEX_PASS="'$PASS'",g' $JAIL_CONFIG
	elif [[ ${VNET_PLUGIN[*]} == *$JAIL* ]]; then
		sed -i '' -e 's,'$IP'="'${!IP}'",'$IP'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			sed -i '' -e 's,'$PORT'="'${!PORT}'",'$PORT'="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[2]}'",g' $JAIL_CONFIG
		else
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
		fi
	else
		if [[ ${CHANGEABLE_PORT[*]} == *$JAIL* ]]; then
			sed -i '' -e 's,'$PORT'="'${!PORT}'",'$PORT'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
		else
			sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		fi
		sed -i '' -e 's,'$IP'="'${!IP}'",'$IP'="'$IOCAGE_SHARED_IP'",g' $JAIL_CONFIG
	fi

	if [[ $JAIL == "webserver" ]]; then
        # initialize file with variables if they don't exists
		if ! grep -q "EMAIL_ADDRESS" $GLOBAL_CONFIG; then
			echo -e "EMAIL_ADDRESS=\""$DEFAULT_EMAIL_ADDRESS"\"" >> $GLOBAL_CONFIG
		fi
		if ! grep -q "MYSQL_ROOT_PASSWORD" $JAIL_CONFIG; then
			echo -e "MYSQL_ROOT_PASSWORD=\"\"" >> $JAIL_CONFIG
		fi
		if ! grep -q "EXTERNAL_GUI" $JAIL_CONFIG; then
			echo -e "EXTERNAL_GUI=\"NO\"" >> $JAIL_CONFIG
		fi			
		if ! grep -q "WORDPRESS_WEB" $JAIL_CONFIG; then
			echo -e "WORDPRESS_WEB=\"NO\"" >> $JAIL_CONFIG
		fi			

		# load updated config file
		. $JAIL_CONFIG

		dialog --title "External access" --yesno "Do you want to make the FreeNAS webGUI accessible from outside your network?" 7 60
		exit_status=$?
        if [ $exit_status == $DIALOG_OK ]; then
			if ! grep -q "FREENAS_IP" $JAIL_CONFIG; then
				echo -e "FREENAS_IP=\""$LOCAL_IP"\"" >> $JAIL_CONFIG
			fi	
			if ! grep -q "FREENAS_PORT" $JAIL_CONFIG; then
				echo -e "FREENAS_PORT=\"80\"" >> $JAIL_CONFIG
			fi	
			# load updated config file
			. $JAIL_CONFIG
			
			exec 3>&1
			FREENASIP=$(dialog --form "Webserver configuration:" 0 0 0 \
			"FreeNAS webGUI Port:" 2 2 "$FREENAS_PORT" 2 30 5 0 \
			2>&1 1>&3)
			exit_status=$?
			exec 3>&-
			
            if [ $exit_status != $DIALOG_OK ]; then
				install_dialog second_time
			else
                FREENASARR=( $FREENASIP )
                sed -i '' -e 's,EXTERNAL_GUI="NO",EXTERNAL_GUI="YES",g' $JAIL_CONFIG
                sed -i '' -e 's,FREENAS_PORT="'$FREENAS_PORT'",FREENAS_PORT="'${FREENASARR[0]}'",g' $JAIL_CONFIG
            fi
		elif [ $exit_status == $DIALOG_CANCEL ]; then
			sed -i '' -e 's,EXTERNAL_GUI="YES",EXTERNAL_GUI="NO",g' $JAIL_CONFIG
        else
            install_dialog second_time
		fi
			
		exec 3>&1
		VALUE=$(dialog --form "Webserver configuration:" 0 0 0 \
		"Email address:" 1 1 "$EMAIL_ADDRESS" 1 30 60 0 \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
        
		if [ $exit_status != $DIALOG_OK ]; then
			install_dialog second_time
		fi
		
		sed -i '' -e 's,EMAIL_ADDRESS="'$EMAIL_ADDRESS'",EMAIL_ADDRESS="'$VALUE'",g' $GLOBAL_CONFIG

		exec 3>&1
		PASS=$(dialog --title "Setting Password:" \
		--clear \
		--insecure \
		--passwordbox "Set MySQL Root password:" 0 0 "$MYSQL_ROOT_PASSWORD" \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
        
		if [ $exit_status != $DIALOG_OK ]; then
			install_dialog second_time
        fi
		
        sed -i '' -e 's,MYSQL_ROOT_PASSWORD="'$MYSQL_ROOT_PASSWORD'",MYSQL_ROOT_PASSWORD="'$PASS'",g' $JAIL_CONFIG
		
		dialog --title "Hosting WordPress Website?" --yesno "Do you want to host a WordPress website?" 7 60
		exit_status=$?
        if [ $exit_status == $DIALOG_OK ]; then
			if ! grep -q "organizr_SUB_DOMAIN" $JAIL_CONFIG; then
				echo -e "organizr_SUB_DOMAIN=\"\"" >> $JAIL_CONFIG
			fi	
			# load updated config file
			. $JAIL_CONFIG
			
			exec 3>&1
			VALUE1=$(dialog --form "Organizr subdomain:" 0 0 0 \
			"Organizr subdomain:" 1 1 "$organizr_SUB_DOMAIN" 1 30 25 0 \
			2>&1 1>&3)
			exit_status=$?
			exec 3>&-
            
			if [ $exit_status != $DIALOG_OK ]; then
				install_dialog second_time
			fi
			
			sed -i '' -e 's,WORDPRESS_WEB="NO",WORDPRESS_WEB="YES",g' $JAIL_CONFIG
			sed -i '' -e 's,organizr_SUB_DOMAIN="'$organizr_SUB_DOMAIN'",organizr_SUB_DOMAIN="'$VALUE1'",g' $JAIL_CONFIG
			config_mysql $JAIL
		elif [ $exit_status == $DIALOG_CANCEL ]; then
			sed -i '' -e 's,WORDPRESS_WEB="YES",WORDPRESS_WEB="NO",g' $JAIL_CONFIG
        else
            install_dialog second_time
		fi
	else
		if [[ $DATABASE_JAILS == *$JAIL* ]]; then  # configure mysql if needed
			config_mysql $JAIL
		fi
	fi
}

config_mysql () {
	JAIL=$1
	MYSQL_USER=$JAIL\_MYSQL_USERNAME
	MYSQL_DATA=$JAIL\_MYSQL_DATABASE
	MYSQL_PASS=$JAIL\_MYSQL_PASSWORD
	DEFAULT_USER=$JAIL\_DEFAULT_USERNAME
	DEFAULT_DATA=$JAIL\_DEFAULT_DATABASE
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
	
	if ! grep -q $MYSQL_USER $JAIL_CONFIG; then
		echo -e $MYSQL_USER"=\""${!DEFAULT_USER}"\"" >> $JAIL_CONFIG
	fi
	if ! grep -q $MYSQL_DATA $JAIL_CONFIG; then
		echo -e $MYSQL_DATA"=\""${!DEFAULT_DATA}"\"" >> $JAIL_CONFIG
	fi
	if ! grep -q $MYSQL_PASS $JAIL_CONFIG; then
		echo -e $MYSQL_PASS"=\"\"" >> $JAIL_CONFIG
	fi
	
	#load updated config file
	. $JAIL_CONFIG
	
	exec 3>&1
	VALUES=$(dialog --form "Webserver configuration:" 0 0 0 \
	"$1 MySQL User:" 1 1 "${!MYSQL_USER}" 1 30 25 0 \
	"$1 MySQL Database:" 2 1 "${!MYSQL_DATA}" 2 30 25 0 \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		install_dialog second_time
	fi
	
	VALUES_ARR=( $VALUES )
	sed -i '' -e 's,'$MYSQL_USER'="'${!MYSQL_USER}'",'$MYSQL_USER'="'${VALUES_ARR[0]}'",g' $JAIL_CONFIG
	sed -i '' -e 's,'$MYSQL_DATA'="'${!MYSQL_DATA}'",'$MYSQL_DATA'="'${VALUES_ARR[1]}'",g' $JAIL_CONFIG

	exec 3>&1
	PASS=$(dialog --title "Setting Password:" \
	--clear \
	--insecure \
	--passwordbox "Set MySQL $1 password:" 0 0 "${!MYSQL_PASS}" \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		install_dialog second_time
	fi

	sed -i '' -e 's,'$MYSQL_PASS'="'${!MYSQL_PASS}'",'$MYSQL_PASS'="'$PASS'",g' $JAIL_CONFIG
}

install_jail () {
	JAIL=$1
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
	# load config files
	. $JAIL_CONFIG
	. $GLOBAL_CONFIG
	
	IP=$JAIL\_IP
	PORT=$JAIL\_PORT
	SUB_DOMAIN=$JAIL\_SUB_DOMAIN

	VERSION="$(uname -r)"
	VERSION=${VERSION//[!0-9,.]/}-RELEASE # take only the version number and pick the RELEASE as IOCAGE base

	iocage activate $IOCAGE_ZPOOL
	
	if [[ $(iocage list) != *$JAIL* ]]; then
		
		if [[ ${CUSTOM_PLUGIN[*]} == *$JAIL* ]]; then
			if [[ ${VNET_PLUGIN[*]} == *$JAIL* ]]; then
				INTERFACE="vnet0"
				iocage fetch -P --name $(dirname $0)/$JAIL/$JAIL.json ip4_addr="$INTERFACE|${!IP}" defaultrouter="$ROUTER_IP" vnet="on"
			else
				iocage fetch -P --name $(dirname $0)/$JAIL/$JAIL.json ip4_addr="$INTERFACE|${!IP}"
			fi
		else
			if [[ ${VNET_PLUGIN[*]} == *$JAIL* ]]; then
				INTERFACE="vnet0"
				iocage fetch --plugins --name $JAIL ip4_addr="$INTERFACE|${!IP}" defaultrouter="$ROUTER_IP" vnet="on"
			else
				iocage fetch --plugins --name $JAIL ip4_addr="$INTERFACE|${!IP}"
			fi
		fi

		mount_storage $JAIL
		
		cp ${JAIL_CONFIG%/*}/* $JAIL_LOCATION/$JAIL/root/root/
		cp $GLOBAL_CONFIG $JAIL_LOCATION/$JAIL/root/root/
		if [ -d "$BACKUP_LOCATION/$JAIL/usr/local/etc/letsencrypt/" ]; then # copy certificates before installing, otherwise certificates will be requested when not necessary
			echo "restoring certificates..."
			mkdir -p $JAIL_LOCATION/$JAIL/root/usr/local/etc/letsencrypt
			rsync -a $BACKUP_LOCATION/$JAIL/usr/local/etc/letsencrypt/ $JAIL_LOCATION/$JAIL/root/usr/local/etc/letsencrypt
			chown -R $USER_NAME:$USER_NAME $JAIL_LOCATION/$JAIL/root/usr/local/etc/letsencrypt/
		fi
		
		if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then # configure mysql if needed
			DATABASE=$JAIL\_MYSQL_DATABASE
			USER=$JAIL\_MYSQL_USERNAME
			PASS=$JAIL\_MYSQL_PASSWORD
			iocage exec webserver bash /root/mysql.sh ${!DATABASE} ${!USER} ${!PASS}
		fi

		# config everything inside the jail
		iocage exec $JAIL pkg install -y bash
		iocage exec $JAIL bash /root/$JAIL.sh

		if [[ $JAIL != "webserver" ]]; then  # configure subdomain
			. $(dirname $0)/webserver/webserver_config.sh
			if [ "${!SUB_DOMAIN}" ]; then
				iocage exec webserver bash /root/subdomain.sh ${!SUB_DOMAIN} ${!IP} ${!PORT}
			else
				iocage exec webserver bash /root/suburl.sh $JAIL ${!IP} ${!PORT}
			fi
		fi
		
		if [ -d "$BACKUP_LOCATION/$JAIL" ]; then
			dialog --title "Restore backup?" --yesno "Do you want to restore the backup?\"?" 7 60
			exit_status=$?
			if [ $exit_status == $DIALOG_OK ]; then
				i=1
				while true; do
					FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf)"
					DEST_FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf | cut -d " " -f1)"
					DEST_FOLDER=${DEST_FOLDER%/*}/
					(( i++ ))
					if [ "$FOLDER" ]; then
						rsync -a $BACKUP_LOCATION/$JAIL$FOLDER $JAIL_LOCATION/$JAIL/root$DEST_FOLDER
						chown -R $USER_NAME:$USER_NAME $JAIL_LOCATION/$JAIL/root$DEST_FOLDER
					else
						break
					fi
				done
				if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then
					. $(dirname $0)/webserver/webserver_config.sh
					MYSQL_DATA=$JAIL\_MYSQL_DATABASE
					iocage exec webserver mysql -u root -p$MYSQL_ROOT_PASSWORD ${!MYSQL_DATA} < $BACKUP_LOCATION/$JAIL/${!MYSQL_DATA}.sql
				fi
				if [[ $JAIL == *"webserver"* ]]; then
					iocage exec webserver mysql -u root -p$MYSQL_ROOT_PASSWORD < $BACKUP_LOCATION/$JAIL/all-databases.sql
				fi
			fi
		fi

		if [ "${!SUB_DOMAIN}" ]; then
			echo "Change ui.json with subdomain"
			sed -i '' -e 's,"adminportal.*,"adminportal": "https://'${!SUB_DOMAIN}'.'$DOMAIN'",g' $JAIL_LOCATION/$JAIL/plugin/ui.json
		elif [[ $JAIL == "webserver" ]]; then
			echo "Change ui.json for webserver"
			sed -i '' -e 's,"adminportal.*,"adminportal": "https://www.'$DOMAIN'",g' $JAIL_LOCATION/$JAIL/plugin/ui.json
		else
			echo "Change ui.json with suburl"
			sed -i '' -e 's,"adminportal.*,"adminportal": "https://www.'$DOMAIN'/'$JAIL'",g' $JAIL_LOCATION/$JAIL/plugin/ui.json
		fi

		iocage restart $JAIL
		dialog --msgbox "$JAIL installed" 0 0
	else
		dialog --msgbox "$JAIL already installed, use the upgrade function in main menu!" 0 0
	fi

}

mount_storage () {
	
	JAIL=$1

	if [[ $JAIL == "" ]]; then # only show dialog when coming from main dialog
		exec 3>&1
		CHOICE=$(dialog --menu "What would you like to do:" 0 0 0 \
		"Edit userdata location" "Edit the userdata folder location" \
		"Edit media location" "Edit the media folder location" \
		"Edit downloads location" "Edit the downloads folder location" \
		"Mount extra storage" "Mount extra storage to a jail/plugin" \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			first
		fi
		
		if [[ $CHOICE == "Edit userdata location" ]]; then
			sed -i '' -e 's,FILE_LOCATION="'$FILE_LOCATION'",FILE_LOCATION="",g' $GLOBAL_CONFIG
		elif [[ $CHOICE == "Edit media location" ]]; then
			sed -i '' -e 's,MEDIA_LOCATION="'$MEDIA_LOCATION'",MEDIA_LOCATION="",g' $GLOBAL_CONFIG
		elif [[ $CHOICE == "Edit downloads location" ]]; then
			sed -i '' -e 's,DOWNLOADS_LOCATION="'$DOWNLOADS_LOCATION'",DOWNLOADS_LOCATION="",g' $GLOBAL_CONFIG
		elif [[ $CHOICE == "Mount extra storage" ]]; then
			exec 3>&1
			JAIL=$(dialog --menu "Mount storage to:" 0 0 0 \
			Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
			Nextcloud "Nextcloud 12" \
			SABnzbd "SABnzbd" \
			Sonarr "Sonarr automatic serice downloader" \
			Radarr "Radarr automatic movie downloader" \
			Plex "Plex Media Server" \
			Emby "Emby Media Server" \
			Tvheadend "Tvheadend TV streaming server" \
			AdGuard "DNS Adblocker"\
			FireFly "Personal finances manager"\
			DSMR "DSMR Reader"\
			2>&1 1>&3)
			exit_status=$?
			exec 3>&-
			
			if [ $exit_status != $DIALOG_OK ]; then
				mount_storage
			fi
			JAIL=${JAIL,,}
			JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
			# load config files
			. $JAIL_CONFIG
			. $GLOBAL_CONFIG
			
			if [[ $(iocage list) == *$JAIL* ]] && [ -f $JAIL_CONFIG ]; then
				exit_status="0"
				while [ $exit_status == $DIALOG_OK ]; do
				{
					dialog --title "Mount more storage to $JAIL?" --yesno "Do you want to mount more storage to $JAIL?\"?" 7 60
					exit_status=$?
					if [ $exit_status == $DIALOG_OK ]; then
						DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose a folder to mount at /mnt on $JAIL" --fselect /mnt/ 14 48)
						exit_status=$?
						if [ $exit_status == $DIALOG_OK ]; then
							chown -R $USER_NAME:$USER_NAME $DATA
							mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/$(basename $DATA)
							iocage fstab -a $JAIL $DATA /mnt/$(basename $DATA) nullfs rw 0 0
							iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/$(basename $DATA)
							iocage restart $JAIL
						fi
					fi		
				}
				done
			else
				dialog --msgbox "Jail does not exists!" 5 50
			fi
		fi
	fi
	
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
	# load config files
	if [[ $1 != "" ]]; then
		. $JAIL_CONFIG
	fi
	. $GLOBAL_CONFIG
	
	if ! grep -q "FILE_LOCATION" $GLOBAL_CONFIG; then
		echo -e "FILE_LOCATION=\"\"" >> $GLOBAL_CONFIG
	fi
	if ! grep -q "MEDIA_LOCATION" $GLOBAL_CONFIG; then
		echo -e "MEDIA_LOCATION=\"\"" >> $GLOBAL_CONFIG
	fi
	if ! grep -q "DOWNLOADS_LOCATION" $GLOBAL_CONFIG; then
		echo -e "DOWNLOADS_LOCATION=\"\"" >> $GLOBAL_CONFIG
	fi
	. $GLOBAL_CONFIG

	if [[ ${FILE_JAILS[*]} == *$JAIL* ]]; then
		if [[ $FILE_LOCATION == "" ]]; then  # if fileserver jail mount user files
			echo "FILE!"
			DATA=$(dialog --title "Mounting storage" --stdout --title "Please choose the userdata dataset location" --fselect /mnt/ 14 48)
			exit_status=$?
			if [ $exit_status == $DIALOG_OK ]; then
				sed -i '' -e 's,FILE_LOCATION="'$FILE_LOCATION'",FILE_LOCATION="'$DATA'",g' $GLOBAL_CONFIG
				if [[ $1 == "" ]]; then
					count=0
					while [ "x${FILE_JAILS[count]}" != "x" ]
					do
						JAIL=${FILE_JAILS[count]}
						JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
						if [ -f $JAIL_CONFIG ]; then
							. $JAIL_CONFIG
							chown -R $USER_NAME:$USER_NAME $DATA
							mkdir -p $JAIL_LOCATION/$JAIL/root/media
							iocage fstab -R 0 $JAIL $DATA /media nullfs rw 0 0 # does not work, we need to get the index first
							iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /media
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/media
					iocage fstab -a $JAIL $DATA /media nullfs rw 0 0
					iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /media
					iocage restart $JAIL
				fi
			else
				mount_storage $JAIL
			fi
		elif [[ $1 != "" ]]; then
			. $GLOBAL_CONFIG
			chown -R $USER_NAME:$USER_NAME $FILE_LOCATION
			mkdir -p $JAIL_LOCATION/$JAIL/root/media
			iocage fstab -a $JAIL $FILE_LOCATION /media nullfs rw 0 0
			iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /media
			iocage restart $JAIL
		fi
	fi

	if [[ ${MEDIA_JAILS[*]} == *$JAIL* ]]; then  # if media jail mount media/download files
		if [[ $MEDIA_LOCATION == "" ]]; then
			DATA=$(dialog --title "Mounting storage" --stdout --title "Please set the media dataset location" --fselect /mnt/ 14 48)
			exit_status=$?
			if [ $exit_status == $DIALOG_OK ]; then
				sed -i '' -e 's,MEDIA_LOCATION="'$MEDIA_LOCATION'",MEDIA_LOCATION="'$DATA'",g' $GLOBAL_CONFIG
				if [[ $1 == "" ]]; then #edit all the X jails
					count=0
					while [ "x${MEDIA_JAILS[count]}" != "x" ]
					do
					   	JAIL=${MEDIA_JAILS[count]}
						JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
						if [ -f $JAIL_CONFIG ]; then
					   		. $JAIL_CONFIG
							chown -R $USER_NAME:$USER_NAME $DATA
							mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/media
					   		iocage fstab -R 0 $JAIL $DATA /mnt/media nullfs rw 0 0 # does not work, we need to get the index first
							iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/media
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/media
					iocage fstab -a $JAIL $DATA /mnt/media nullfs rw 0 0
					iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/media
					iocage restart $JAIL
				fi
			else
				mount_storage $JAIL
			fi
		elif [[ $1 != "" ]]; then
			. $GLOBAL_CONFIG
			chown -R $USER_NAME:$USER_NAME $MEDIA_LOCATION
			mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/media
			iocage fstab -a $JAIL $MEDIA_LOCATION /mnt/media nullfs rw 0 0
			iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/media
			iocage restart $JAIL
		fi

		if [[ $DOWNLOADS_LOCATION == "" ]]; then
			DATA=$(dialog --title "Mounting storage" --stdout --title "Please set the download dataset location" --fselect /mnt/ 14 48)
			exit_status=$?
			if [ $exit_status == $DIALOG_OK ]; then
				sed -i '' -e 's,DOWNLOADS_LOCATION="'$DOWNLOADS_LOCATION'",DOWNLOADS_LOCATION="'$DATA'",g' $GLOBAL_CONFIG
				if [[ $1 == "" ]]; then
					count=0
					while [ "x${MEDIA_JAILS[count]}" != "x" ]
					do
					   	JAIL=${MEDIA_JAILS[count]}
					   	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
						if [ -f $JAIL_CONFIG ]; then
							. $JAIL_CONFIG
							chown -R $USER_NAME:$USER_NAME $DATA
							mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/downloads
							iocage fstab -R 1 $JAIL $DATA /mnt/downloads nullfs rw 0 0 # does not work, we need to get the index first
							iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/downloads
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/downloads
					iocage fstab -a $JAIL $DATA /mnt/downloads nullfs rw 0 0
					iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/downloads
					iocage restart $JAIL
				fi
			else
				mount_storage $JAIL
			fi
		elif [[ $1 != "" ]]; then
			. $GLOBAL_CONFIG
			chown -R $USER_NAME:$USER_NAME $DOWNLOADS_LOCATION
			mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/downloads
			iocage fstab -a $JAIL $DOWNLOADS_LOCATION /mnt/downloads nullfs rw 0 0
			iocage exec $JAIL chown -R $USER_NAME:$USER_NAME /mnt/downloads
			iocage restart $JAIL
		fi
	fi

	if [[ $1 == "" ]]; then # if from main dialog, stay in mount_storage
		mount_storage
	fi
}

delete_jail () {
    backup="0"

	exec 3>&1
	JAIL=$(dialog --menu "Delete following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
	Nextcloud "Nextcloud 12" \
	SABnzbd "SABnzbd" \
	Sonarr "Sonarr automatic serice downloader" \
	Radarr "Radarr automatic movie downloader" \
	Plex "Plex Media Server" \
	Emby "Emby Media Server" \
	Tvheadend "Tvheadend TV streaming server" \
	AdGuard "DNS Adblocker"\
	FireFly "Personal finances manager"\
	DSMR "DSMR Reader"\
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		first
	fi
	
	JAIL=${JAIL,,}
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
	# load config files
	. $JAIL_CONFIG
	. $GLOBAL_CONFIG
	. $(dirname $0)/webserver/webserver_config.sh

	if [[ $(iocage list) == *$JAIL* ]]; then
		dialog --title "Backup before deleting" \
		--yesno "Do you want to make a config backup before deleting $JAIL?" 7 60
		exit_status=$?
		if [ $exit_status == $DIALOG_OK ]; then
			backup="1"
			backup_jail $JAIL			
		elif [ $exit_status == $DIALOG_CANCEL ]; then
			backup="0"
		else
			delete_jail
		fi
		
		dialog --title "Delete Program/Jail" \
		--yesno "Are you sure you want to permanently delete $JAIL?" 7 60
		exit_status=$?
		if [ $exit_status == $DIALOG_OK ]; then
			iocage stop $JAIL
			iocage destroy $JAIL -f
			iocage destroy $JAIL -f
			if [ $backup != "1" ]; then
				dialog --title "Delete backup" \
				--yesno "Do you want to delete the backup of $JAIL also?" 7 60
				exit_status=$?
				if [ $exit_status == $DIALOG_OK ]; then
					rm -rf $BACKUP_LOCATION/$JAIL
				fi
			fi
			rm -f $JAIL_LOCATION/webserver/root/usr/local/etc/nginx/sites/$JAIL.conf
			sed -i '' -e '/.*'$JAIL'.*/d' $JAIL_LOCATION/webserver/root/usr/local/etc/nginx/standard.conf
			if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then
				MYSQL_DATA=$JAIL\_MYSQL_DATABASE
				iocage exec webserver mysql -u root -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS ${!MYSQL_DATA};"
			fi
			dialog --msgbox "$JAIL deleted" 5 30
		else
			dialog --msgbox "$JAIL NOT deleted, operation canceled by user!" 5 30
		fi
	else
		dialog --msgbox "$JAIL does not exists!" 5 50
	fi
	delete_jail
}

backup_jail () {

	JAIL=$1

	if ! grep -q "JAIL_LOCATION" $GLOBAL_CONFIG; then
		echo -e "JAIL_LOCATION=\""$DEFAULT_JAIL_LOCATION"\"" >> $GLOBAL_CONFIG
	fi
	if ! grep -q "BACKUP_LOCATION" $GLOBAL_CONFIG; then
		echo -e "\nBACKUP_LOCATION=\""$DEFAULT_BACKUP_LOCATION"\"" >> $GLOBAL_CONFIG
	fi
	
	#load updated config file
	. $GLOBAL_CONFIG
	if [[ $JAIL == "" ]]; then
		exec 3>&1
		JAIL=$(dialog --form "IOCAGE Jail location:" 0 0 0 \
		"Jail location (starting with \"/\" and without last \"/\")" 1 1 "$JAIL_LOCATION" 1 60 25 0 \
		"Backup location (starting with \"/\" and without last \"/\")" 2 1 "$BACKUP_LOCATION" 2 60 25 0 \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			first
		fi
		
		JAIL_VALUES=( $JAIL )
		sed -i '' -e 's,JAIL_LOCATION="'$JAIL_LOCATION'",JAIL_LOCATION="'${JAIL_VALUES[0]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,BACKUP_LOCATION="'$BACKUP_LOCATION'",BACKUP_LOCATION="'${JAIL_VALUES[1]}'",g' $GLOBAL_CONFIG
		mkdir -p $BACKUP_LOCATION
		
		exec 3>&1
		JAIL=$(dialog --menu "Backup following programs:" 0 0 0 \
		Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
		Nextcloud "Nextcloud 12" \
		SABnzbd "SABnzbd" \
		Sonarr "Sonarr automatic serice downloader" \
		Radarr "Radarr automatic movie downloader" \
		Plex "Plex Media Server" \
		Emby "Emby Media Server" \
		Tvheadend "Tvheadend TV streaming server" \
		AdGuard "DNS Adblocker"\
		FireFly "Personal finances manager"\
		DSMR "DSMR Reader"\
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			first
		fi
	fi
	JAIL=${JAIL,,}
	
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"
	JAIL_BACKUP=$(dirname $0)"/"$JAIL"/backup.conf"

	# load config files
	. $JAIL_CONFIG
	. $GLOBAL_CONFIG
	
	mkdir -p $BACKUP_LOCATION/$JAIL
	iocage stop $JAIL
	i=1
	while true; do
		FOLDER="$(sed -n ''$i'p' $JAIL_BACKUP)"
		DEST_FOLDER="$(sed -n ''$i'p' $JAIL_BACKUP | cut -d " " -f1)"
		DEST_FOLDER=${DEST_FOLDER%/*}/
		(( i++ ))
		if [ "$FOLDER" ]; then
			mkdir -p $BACKUP_LOCATION/$JAIL$DEST_FOLDER
			rsync -a --delete $JAIL_LOCATION/$JAIL/root${FOLDER} $BACKUP_LOCATION/$JAIL$DEST_FOLDER
		else
			break
		fi
	done
	iocage start $JAIL
	if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then
		. $(dirname $0)/webserver/webserver_config.sh
		MYSQL_DATA=$JAIL\_MYSQL_DATABASE
		iocage exec webserver mysqldump --opt --set-gtid-purged=OFF -u root -p$MYSQL_ROOT_PASSWORD ${!MYSQL_DATA} > $BACKUP_LOCATION/$JAIL/${!MYSQL_DATA}.sql
		if [[ $JAIL == *"webserver"* ]]; then
			iocage exec webserver mysqldump --opt --all-databases --set-gtid-purged=OFF -u root -p$MYSQL_ROOT_PASSWORD > $BACKUP_LOCATION/$JAIL/all-databases.sql
		fi
	fi
	
	dialog --msgbox "Config of $JAIL backuped!" 5 50
	
	if [[ $1 == "" ]]; then
		first
	fi
}

upgrade_jail () {
	dialog --msgbox "Not implemented yet!" 5 30
	first
}

touch $GLOBAL_CONFIG || exit
. $GLOBAL_CONFIG

if [[ $1 == "" ]]; then
	cd /root/freenas-jails && git reset --hard
	cd /root/freenas-jails && git pull
	bash /root/freenas-jails/freenas-jails.sh second_time
else
	first
fi

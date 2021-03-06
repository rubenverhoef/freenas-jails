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
GLOBAL_CONFIG=$(dirname $0)"/config.sh"
DATABASE_JAILS=(webserver nextcloud firefly)
MEDIA_JAILS=(plex sonarr radarr sabnzbd tvheadend)
FILE_JAILS=(nextcloud)

# DEFAULT VALUES:
DEFAULT_DOMAIN="example.com"
DEFAULT_IOCAGE_ZPOOL="ssd"
DEFAULT_JAIL_LOCATION="/mnt/iocage/jails"
DEFAULT_BACKUP_LOCATION="/mnt/data/backup_jails"
DEFAULT_EMAIL_ADDRESS="admin@example.com"

webserver_DEFAULT_USERNAME="wordpress_user"
webserver_DEFAULT_DATABASE="wordpress"

nextcloud_DEFAULT_USERNAME="nextcloud_user"
nextcloud_DEFAULT_DATABASE="nextcloud"

firefly_DEFAULT_USERNAME="firefly_user"
firefly_DEFAULT_DATABASE="firefly"

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
		"Backup location (starting with \"/\" and without last \"/\")" 2 1 "$BACKUP_LOCATION" 2 60 25 0 \
		"Please create a USER in the TrueNAS WebGUI!!" 3 1 "" 3 60 0 0 \
		"User name:" 4 1 "$USER_NAME" 4 60 25 0 \
		"User ID (UID):" 5 1 "$USER_ID" 5 60 25 0 \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ $exit_status != $DIALOG_OK ]; then
			first
		fi
		
		GLOBAL=( $JAIL )
		
		#save new config variables in global config file
		sed -i '' -e 's,IOCAGE_ZPOOL="'$IOCAGE_ZPOOL'",IOCAGE_ZPOOL="'${GLOBAL[0]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,BACKUP_LOCATION="'$BACKUP_LOCATION'",BACKUP_LOCATION="'${GLOBAL[1]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,USER_NAME="'$USER_NAME'",USER_NAME="'${GLOBAL[2]}'",g' $GLOBAL_CONFIG
		sed -i '' -e 's,USER_ID="'$USER_ID'",USER_ID="'${GLOBAL[3]}'",g' $GLOBAL_CONFIG
    fi
	
	exec 3>&1
	PROGRAM=$(dialog --menu "Install following program:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
	Nextcloud "Nextcloud" \
	SABnzbd "SABnzbd" \
	Sonarr "Sonarr automatic serice downloader" \
	Radarr "Radarr automatic movie downloader" \
	Plex "Plex Media Server" \
	Tvheadend "Tvheadend TV streaming server" \
	AdGuard "DNS Adblocker"\
	FireFly "Personal finances manager"\
	DSMR "DSMR Reader"\
	Zigbee2MQTT "Zigbee2MQTT"\
	Unifi "Unifi Controller"\
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
	JAIL_CONFIG=$(dirname $0)"/"$JAIL"/"$JAIL"_config.sh"

    # make directory and file if not exists already
	mkdir -p ${JAIL_CONFIG%/*}/
	touch  $JAIL_CONFIG || exit
	
    # initialize file with variables if they don't exists
	if [[ $JAIL == *"webserver"* ]]; then
		if ! grep -q "DOMAIN" $GLOBAL_CONFIG; then
			echo -e "DOMAIN=\""$DEFAULT_DOMAIN"\"" >> $GLOBAL_CONFIG
		fi
	else
		if ! grep -q $SUB_DOMAIN $JAIL_CONFIG; then
			echo -e $SUB_DOMAIN"=\"\"" >> $JAIL_CONFIG
		fi
	fi
	if [[ $JAIL == "plex" ]]; then
		if ! grep -q "PLEX_USER" $JAIL_CONFIG; then
			echo -e "PLEX_USER=\""$PLEX_USER"\"" >> $JAIL_CONFIG
		fi
		if ! grep -q "PLEX_PASS" $JAIL_CONFIG; then
			echo -e "PLEX_PASS=\""$PLEX_PASS"\"" >> $JAIL_CONFIG
		fi
	fi
	if [[ $JAIL == "firefly" ]]; then
		if ! grep -q "GITHUB_API" $JAIL_CONFIG; then
			echo -e "GITHUB_API=\""$GITHUB_API"\"" >> $JAIL_CONFIG
		fi
	fi
	
	# load updated config files
	. $JAIL_CONFIG
	. $GLOBAL_CONFIG
	
	exec 3>&1
	if [[ $JAIL == "webserver" ]]; then
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Domain name (without https://www.)" 1 1 "$DOMAIN" 1 40 25 0 \
		2>&1 1>&3)
	elif [[ $JAIL == "plex" ]]; then
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Keep emtpy for no Subdomain" 1 1 "" 1 30 0 0 \
		"Subdomain name" 2 1 "${!SUB_DOMAIN}" 2 30 25 0 \
		"Blank for normal plex" 3 1 "" 3 30 0 0 \
		"Plex.tv username" 4 1 "$PLEX_USER" 4 30 25 0 \
		2>&1 1>&3)
	elif [[ $JAIL == "firefly" ]]; then
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Keep emtpy for no Subdomain" 1 1 "" 1 30 0 0 \
		"Subdomain name" 2 1 "${!SUB_DOMAIN}" 2 30 25 0 \
		"Github API key for composer. Create one her:" 3 1 "" 3 30 0 0 \
		"https://github.com/settings/tokens/new?scopes=repo&description=Composer+on+firefly" 4 1 "" 4 30 0 0 \
		"GitHub API" 5 1 "$GITHUB_API" 5 30 45 0 \
		2>&1 1>&3)
	else
		VALUES=$(dialog --form "$1 configuration:" 0 0 0 \
		"Keep emtpy for no Subdomain" 1 1 "" 1 30 0 0 \
		"Subdomain name" 2 1 "${!SUB_DOMAIN}" 2 30 25 0 \
		2>&1 1>&3)
	fi
	exit_status=$?
	exec 3>&-

	if [ $exit_status != $DIALOG_OK ]; then
		install_dialog second_time
	fi

    # save new variables in jail config file
	JAIL_VALUES=( $VALUES )

	if [[ $JAIL == "webserver" ]]; then
		sed -i '' -e 's,DOMAIN="'$DOMAIN'",DOMAIN="'${JAIL_VALUES[0]}'",g' $GLOBAL_CONFIG
	elif [[ $JAIL == "plex" ]]; then
		sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		sed -i '' -e 's,PLEX_USER="'$PLEX_USER'",PLEX_USER="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
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
	elif [[ $JAIL == "firefly" ]]; then
		sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
		sed -i '' -e 's,GITHUB_API="'$GITHUB_API'",GITHUB_API="'${JAIL_VALUES[1]}'",g' $JAIL_CONFIG
	else
		sed -i '' -e 's,'$SUB_DOMAIN'="'${!SUB_DOMAIN}'",'$SUB_DOMAIN'="'${JAIL_VALUES[0]}'",g' $JAIL_CONFIG
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

		dialog --title "External access" --yesno "Do you want to make the TrueNAS webGUI accessible from outside your network?" 7 60
		exit_status=$?
        if [ $exit_status == $DIALOG_OK ]; then
			if ! grep -q "NAS_IP" $JAIL_CONFIG; then
				echo -e "NAS_IP=\""$LOCAL_IP"\"" >> $JAIL_CONFIG
			fi	
			if ! grep -q "NAS_PORT" $JAIL_CONFIG; then
				echo -e "NAS_PORT=\"80\"" >> $JAIL_CONFIG
			fi	
			# load updated config file
			. $JAIL_CONFIG
			
			exec 3>&1
			NASIP=$(dialog --form "Webserver configuration:" 0 0 0 \
			"TrueNAS webGUI Port:" 2 2 "$NAS_PORT" 2 30 5 0 \
			2>&1 1>&3)
			exit_status=$?
			exec 3>&-
			
            if [ $exit_status != $DIALOG_OK ]; then
				install_dialog second_time
			else
                NASARR=( $NASIP )
                sed -i '' -e 's,EXTERNAL_GUI="NO",EXTERNAL_GUI="YES",g' $JAIL_CONFIG
                sed -i '' -e 's,NAS_PORT="'$NAS_PORT'",NAS_PORT="'${NASARR[0]}'",g' $JAIL_CONFIG
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
		if [[ ${DATABASE_JAILS[*]} == *$JAIL* ]]; then  # configure mysql if needed
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
	
	SUB_DOMAIN=$JAIL\_SUB_DOMAIN

	VERSION="$(uname -r)"
	VERSION=${VERSION//[!0-9,.]/}-RELEASE # take only the version number and pick the RELEASE as IOCAGE base

	iocage activate $IOCAGE_ZPOOL
	
	if [[ $(iocage list) != $JAIL ]]; then
		iocage fetch -P $(dirname $0)/$JAIL/$JAIL.json
		iocage exec $JAIL "pw useradd -n $USER_NAME -u $USER_ID -d /nonexistent -s /usr/sbin/nologin"
		mount_storage $JAIL
		
		if [ -d "$BACKUP_LOCATION/$JAIL/usr/local/etc/letsencrypt/" ]; then # copy certificates before installing, otherwise certificates will be requested when not necessary
			echo "restoring certificates..."
			mkdir -p $JAIL_LOCATION/$JAIL/root/usr/local/etc/letsencrypt
			rsync -a $BACKUP_LOCATION/$JAIL/usr/local/etc/letsencrypt/ $JAIL_LOCATION/$JAIL/root/usr/local/etc/letsencrypt
		fi
		
		if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then # configure mysql if needed
			DATABASE=$JAIL\_MYSQL_DATABASE
			USER=$JAIL\_MYSQL_USERNAME
			PASS=$JAIL\_MYSQL_PASSWORD
			iocage exec webserver "bash /root/mysql.sh ${!DATABASE} ${!USER} ${!PASS}"
		fi

		RESTORE=0
		if [ -d "$BACKUP_LOCATION/$JAIL" ]; then
			dialog --title "Restore backup?" --yesno "Do you want to restore the backup?\"?" 7 60
			exit_status=$?
			if [ $exit_status == $DIALOG_OK ]; then
				RESTORE=1
				. $(dirname $0)/webserver/webserver_config.sh
				if [[ $JAIL == *"webserver"* ]]; then
					rsync -a --delete $BACKUP_LOCATION/$JAIL/all-databases.sql $JAIL_LOCATION/webserver/root/root
					iocage exec webserver "mysql -u root -p'$MYSQL_ROOT_PASSWORD' < root/all-databases.sql"
					rm -rf $JAIL_LOCATION/webserver/root/root/all-databases.sql
				else
					if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then
						MYSQL_DATA=$JAIL\_MYSQL_DATABASE
						rsync -a --delete $BACKUP_LOCATION/$JAIL/${!MYSQL_DATA}.sql $JAIL_LOCATION/webserver/root/root
						iocage exec webserver "mysql -u root -p'$MYSQL_ROOT_PASSWORD' ${!MYSQL_DATA} < root/${!MYSQL_DATA}.sql"
						rm -rf $JAIL_LOCATION/webserver/root/root/${!MYSQL_DATA}.sql
					fi
				fi

				i=1
				while true; do
					FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf)"
					DEST_FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf | cut -d " " -f1)"
					DEST_FOLDER=${DEST_FOLDER%/*}/
					(( i++ ))
					if [ "$FOLDER" ]; then
						rsync -a $BACKUP_LOCATION/$JAIL$FOLDER $JAIL_LOCATION/$JAIL/root$DEST_FOLDER
					else
						break
					fi
				done
			fi
		fi

		# config everything inside the jail
		iocage exec $JAIL "pkg install -y bash"
		if [ -f "$(dirname $0)/$JAIL/$JAIL.sh" ]; then
			cp ${JAIL_CONFIG%/*}/* $JAIL_LOCATION/$JAIL/root/root/
			cp $GLOBAL_CONFIG $JAIL_LOCATION/$JAIL/root/root/
			iocage exec $JAIL "bash /root/$JAIL.sh"
		fi
		if [ -f "$(dirname $0)/$JAIL/config-$JAIL.sh" ]; then
			bash "$(dirname $0)/$JAIL/config-$JAIL.sh"
		fi

		if [[ $JAIL != "webserver" ]]; then  # configure subdomain
			. $(dirname $0)/webserver/webserver_config.sh
			PORT=$(perl -nle 'print $1 if /\:(.[0-9]*)\)/' $(dirname $0)/$JAIL/$JAIL.json)
			SCHEME=$(cat $(dirname $0)/$JAIL/$JAIL.json | jq -r '.web_scheme')
			if [ "$SCHEME" == "null" ]; then
				SCHEME="http"
			fi

			if [ ! -z $PORT ]; then
				if [ "${!SUB_DOMAIN}" ]; then
					iocage exec webserver "bash /root/subdomain.sh ${!SUB_DOMAIN} $LOCAL_IP $PORT $SCHEME"
				else
					iocage exec webserver "bash /root/suburl.sh $JAIL $LOCAL_IP $PORT $SCHEME"
				fi
			fi
		fi
		
		if [ $RESTORE -eq 1 ]; then
			i=1
			while true; do
				FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf)"
				DEST_FOLDER="$(sed -n ''$i'p' ${JAIL_CONFIG%/*}/backup.conf | cut -d " " -f1)"
				DEST_FOLDER=${DEST_FOLDER%/*}/
				(( i++ ))
				if [ "$FOLDER" ]; then
					rsync -a $BACKUP_LOCATION/$JAIL$FOLDER $JAIL_LOCATION/$JAIL/root$DEST_FOLDER
				else
					break
				fi
			done
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
			Nextcloud "Nextcloud" \
			SABnzbd "SABnzbd" \
			Sonarr "Sonarr automatic serice downloader" \
			Radarr "Radarr automatic movie downloader" \
			Plex "Plex Media Server" \
			Tvheadend "Tvheadend TV streaming server" \
			AdGuard "DNS Adblocker"\
			FireFly "Personal finances manager"\
			DSMR "DSMR Reader"\
			Zigbee2MQTT "Zigbee2MQTT"\
			Unifi "Unifi Controller"\
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
							iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/$(basename $DATA)"
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
							iocage exec "$JAIL chown -R $USER_NAME:$USER_NAME /media"
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/media
					iocage fstab -a $JAIL $DATA /media nullfs rw 0 0
					iocage exec "$JAIL chown -R $USER_NAME:$USER_NAME /media"
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
			iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /media"
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
							iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/media"
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/media
					iocage fstab -a $JAIL $DATA /mnt/media nullfs rw 0 0
					iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/media"
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
			iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/media"
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
							iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/downloads"
							iocage restart $JAIL
						fi
						count=$(( $count + 1 ))
					done
				else
					. $GLOBAL_CONFIG
					chown -R $USER_NAME:$USER_NAME $DATA
					mkdir -p $JAIL_LOCATION/$JAIL/root/mnt/downloads
					iocage fstab -a $JAIL $DATA /mnt/downloads nullfs rw 0 0
					iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/downloads"
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
			iocage exec $JAIL "chown -R $USER_NAME:$USER_NAME /mnt/downloads"
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
	Nextcloud "Nextcloud" \
	SABnzbd "SABnzbd" \
	Sonarr "Sonarr automatic serice downloader" \
	Radarr "Radarr automatic movie downloader" \
	Plex "Plex Media Server" \
	Tvheadend "Tvheadend TV streaming server" \
	AdGuard "DNS Adblocker"\
	FireFly "Personal finances manager"\
	DSMR "DSMR Reader"\
	Zigbee2MQTT "Zigbee2MQTT"\
	Unifi "Unifi Controller"\
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
			iocage stop $JAIL"_old"
			iocage destroy $JAIL"_old" --recursive
			iocage stop $JAIL
			iocage rename $JAIL $JAIL"_old"
			iocage set boot=no $JAIL"_old"
			iocage destroy $JAIL --recursive
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
				iocage exec webserver "mysql -u root -p'$MYSQL_ROOT_PASSWORD' -e \"DROP DATABASE IF EXISTS ${!MYSQL_DATA};\""
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
		Nextcloud "Nextcloud" \
		SABnzbd "SABnzbd" \
		Sonarr "Sonarr automatic serice downloader" \
		Radarr "Radarr automatic movie downloader" \
		Plex "Plex Media Server" \
		Tvheadend "Tvheadend TV streaming server" \
		AdGuard "DNS Adblocker"\
		FireFly "Personal finances manager"\
		DSMR "DSMR Reader"\
		Zigbee2MQTT "Zigbee2MQTT"\
		Unifi "Unifi Controller"\
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

	. $(dirname $0)/webserver/webserver_config.sh
	if [[ $JAIL == *"webserver"* ]]; then
		iocage start webserver
		iocage exec webserver "mysqldump --opt --all-databases --set-gtid-purged=OFF -u root -p'$MYSQL_ROOT_PASSWORD' > root/all-databases.sql"
		rsync -a --delete $JAIL_LOCATION/webserver/root/root/all-databases.sql $BACKUP_LOCATION/$JAIL
		rm -rf $JAIL_LOCATION/webserver/root/root/all-databases.sql
	else
		if grep -q "MYSQL.*_DATABASE" $JAIL_CONFIG; then
			MYSQL_DATA=$JAIL\_MYSQL_DATABASE
			iocage exec webserver "mysqldump --opt --set-gtid-purged=OFF -u root -p'$MYSQL_ROOT_PASSWORD' ${!MYSQL_DATA} > root/${!MYSQL_DATA}.sql"
			rsync -a --delete $JAIL_LOCATION/webserver/root/root/${!MYSQL_DATA}.sql $BACKUP_LOCATION/$JAIL
			rm -rf $JAIL_LOCATION/webserver/root/root/${!MYSQL_DATA}.sql
		fi
	fi

	iocage start $JAIL

	
	dialog --msgbox "Config of $JAIL backuped!" 5 50
	
	if [[ $1 == "" ]]; then
		first
	fi
}

upgrade_jail () {
	exec 3>&1
	JAIL=$(dialog --menu "Upgrade following programs:" 0 0 0 \
	Webserver "NGINX, MySQL, WordPress, phpMyAdmin, HTTPS(Let's Encrypt)" \
	Nextcloud "Nextcloud" \
	SABnzbd "SABnzbd" \
	Sonarr "Sonarr automatic serice downloader" \
	Radarr "Radarr automatic movie downloader" \
	Plex "Plex Media Server" \
	Tvheadend "Tvheadend TV streaming server" \
	AdGuard "DNS Adblocker"\
	FireFly "Personal finances manager"\
	DSMR "DSMR Reader"\
	Zigbee2MQTT "Zigbee2MQTT"\
	Unifi "Unifi Controller"\
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-
	
	if [ $exit_status != $DIALOG_OK ]; then
		first
	fi
	
	JAIL=${JAIL,,}

	# backup
	backup_jail $JAIL

	# rename to _old
	iocage stop $JAIL"_old"
	iocage destroy $JAIL"_old" --recursive
	iocage stop $JAIL
	ALL_FSTAB=$(iocage fstab $JAIL -l -h | grep --invert "releases")

	iocage rename $JAIL $JAIL"_old"
	iocage set boot=no $JAIL"_old"

	# install new one
	install_jail $JAIL

	first
}

touch $GLOBAL_CONFIG || exit
. $GLOBAL_CONFIG

if [[ $1 == "" ]]; then
	cd "$(dirname "$0")" && git reset --hard
	cd "$(dirname "$0")" && git pull
	bash "$0" second_time
else
	first
fi

#!/bin/bash

#cd /proxy
# timedatectl set-timezone Europe/Amsterdam
# pip install sqlparse --break-system-packages

while ! mysqladmin ping -h"db" --silent; do
		echo "Waiting for db"
		sleep 5
	done
	echo "DB appears online!"
	
chown -R www-data:www-data /var/www/html
	
# Path to the target init file
TARGET_FILE="/var/www/html/init.sh"

# Check if the file exists and is executable
if [[ -f "$TARGET_FILE" ]]; then
    echo "Found $TARGET_FILE. Executing..."
    bash "$TARGET_FILE"
else
    echo "File $TARGET_FILE not found. Skip it."
fi
	
#/usr/sbin/apache2ctl -D FOREGROUND &
/usr/sbin/apache2ctl -D FOREGROUND

#python3 sql_proxy.py

#!/bin/bash

echo "Changing dir ownership..."
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html

if [[ -f "/var/www/html/.user.ini" ]]; then
    echo "COPYING .user.ini"
    cp /var/www/html/.user.ini "$PHP_INI_DIR/php.ini"
fi

# Path to the target init file
TARGET_FILE="/var/www/html/init.sh"

# Check if the file exists and is executable
if [[ -f "$TARGET_FILE" ]]; then
    echo "Found $TARGET_FILE. Executing..."
    bash "$TARGET_FILE"
else
    echo "The WUT does not have $TARGET_FILE . Skip it."
fi

META_FILE="/var/www/html/instr.meta"
if [[ -f "$META_FILE" ]]; then
    cp $META_FILE /temp/instr.meta
else
    echo "File $META_FILE does not exist."
fi

apt update && apt install -y mariadb-client
echo "Waiting for database to start..."
# while ! mysqladmin ping -h"db" --silent; do
while ! mysqladmin ping -h db --ssl=0 --silent; do
    echo "Waiting for db"
    sleep 1
done
echo "DB appears online!"

/usr/sbin/apache2ctl -D FOREGROUND &

tail -f /dev/null
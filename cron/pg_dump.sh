#!/bin/bash

# Parameters
DB_USERNAME="aviatx_pg"
DB_NAME="aviatx"
DB_BACKUP_DIR="/srv/aviatx/backup/db"
# REMOTE_SERVER_IP="remote_server_ip"
# REMOTE_USERNAME="remote_username"
# PRIVATE_KEY="/path/to/your/private_key"

# Retrieve the PostgreSQL password from the config.fact file
PG_PASSWORD=$(grep -oP '(?<=pg_password=).+' /etc/ansible/facts.d/config.fact)

# Create the backup directory if it doesn't exist
if [ ! -d "$DB_BACKUP_DIR" ]; then
  mkdir -p "$DB_BACKUP_DIR"
fi

# Create a backup of the database using the retrieved password
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$DB_BACKUP_DIR/$DB_NAME-$TIMESTAMP.sql"
PGPASSWORD="$PG_PASSWORD" pg_dump -U "$DB_USERNAME" -h localhost "$DB_NAME" > "$BACKUP_FILE"

# Send the backup file to the remote server
# scp -i "$PRIVATE_KEY" "$BACKUP_FILE" "$REMOTE_USERNAME@$REMOTE_SERVER_IP:/path/to/destination/"

# Unset the PGPASSWORD environment variable
unset PGPASSWORD

# Delete outdated backups (older than 7 days)
find "$DB_BACKUP_DIR" -type f -name "$DB_NAME-*.sql" -mtime +7 -exec rm {} \;


# add to cron
# chmod +x pg_dump.sh
# crontab -e
# 0 2 * * * /srv/aviatx/cron/pg_dump.sh

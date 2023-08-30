#!/bin/bash

# Backup directory and settings
SRC_DIR="/srv/aviatx/platform/media/upload/"
BACKUP_DIR="/srv/aviatx/backup/files"
BACKUP_PREFIX="aviatx_upload_backup"

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
fi

# Create a backup of files with zip compression
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${BACKUP_PREFIX}_$TIMESTAMP.zip"
zip -r "$BACKUP_FILE" "$SRC_DIR"

# Delete outdated backups (older than 7 days)
find "$BACKUP_DIR" -type f -name "${BACKUP_PREFIX}_*.zip" -mtime +7 -exec rm {} \;


# add to cron
# chmod +x media_dump.sh
# crontab -e
# 0 4 * * * /srv/aviatx/cron/media_dump.sh

# подумать над использованием rsync, duplicati или чего-то более умного

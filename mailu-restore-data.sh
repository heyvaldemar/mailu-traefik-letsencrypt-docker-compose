#!/bin/bash

# # mailu-restore-data.sh Description
# Restores mailu's data directory from a backup set taken by the backups service.
# 1. **List Backups**: shows the archives in the backups volume.
# 2. **Select Backup**: you paste the timestamp of the set to restore (the part after the name).
# 3. **Stop Service**: mailu is stopped so nothing writes to the data directory.
# 4. **Restore**: the data archive is unpacked over the data directory, then each SQLite
#    database is restored from its consistent copy.
# 5. **Start Service**: mailu is started again.
# Make it executable once: `chmod +x mailu-restore-data.sh`

APP_CONTAINER="$(docker compose -p mailu ps -q admin)"
BACKUPS_CONTAINER="$(docker compose -p mailu ps -q backups)"
BACKUP_PATH="/srv/mailu/backups"
DB_NAME="mailu-database-backup"
DATA_NAME="mailu-data-backup"

echo "--> All available backup sets (timestamp = the part after the name):"
docker exec "$BACKUPS_CONTAINER" sh -c "ls -1 $BACKUP_PATH"

echo "--> Paste the timestamp of the set to restore and press [ENTER]
--> Example: YYYY-MM-DD_hh-mm"
echo -n "--> "
read -r STAMP
case "$STAMP" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "--> That is not a timestamp" >&2; exit 1 ;;
esac

echo "--> Stopping mailu..."
docker stop "$APP_CONTAINER" > /dev/null

echo "--> Restoring the data directory from $DATA_NAME-$STAMP.tar.gz..."
docker exec "$BACKUPS_CONTAINER" sh -c "tar -C / -xzpf $BACKUP_PATH/$DATA_NAME-$STAMP.tar.gz" || { echo "--> data archive restore FAILED" >&2; docker start "$APP_CONTAINER" > /dev/null; exit 1; }
# shellcheck disable=SC2043
for db in main.db; do
  base="${db%%.*}"
  echo "--> Restoring database $db from $DB_NAME-$base-$STAMP.sqlite3.gz..."
  docker exec "$BACKUPS_CONTAINER" sh -c "rm -f /data/$db /data/$db-wal /data/$db-shm && gunzip -c $BACKUP_PATH/$DB_NAME-$base-$STAMP.sqlite3.gz > /data/$db" || { echo "--> database restore FAILED" >&2; docker start "$APP_CONTAINER" > /dev/null; exit 1; }
done
echo "--> Recovery completed..."

echo "--> Starting mailu..."
docker start "$APP_CONTAINER" > /dev/null

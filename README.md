# Setup process

## Step 1: Run setup script

sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/andrewromm/aviatx_setup/master/setup.sh)"

## Step 2: Restore pg_db

sudo --login --user=postgres

pg_restore -U postgres -Ft -d db < db.tar
psql -d mydatabase -f /path/to/backup.sql

pg_dump aviatx > db.sql

cd /var/lib/postgresql/

## DOCKER

export DOCKER_GROUP_ID=$(getent group docker | cut -d: -f3)

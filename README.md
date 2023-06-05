# Setup process

## Step 1: Run setup script

sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/andrewromm/aviatx_setup/master/setup.sh)"


## Step 2: Restore pg_db

sudo --login --user=postgres

pg_restore -U postgres -Ft -d db < db.tar


pg_dump aviatx > db.sql

cd /var/lib/postgresql/
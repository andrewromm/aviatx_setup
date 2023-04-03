# Setup process

## Step 1: Create ssh key
Note: without passphrase

ssh-keygen -o -t rsa -C "andrew.romm@gmail.com" -f /srv/aviatx/ssh/aviatx_rsa -N ""
cat /srv/aviatx/ssh/aviatx_rsa.pub

## Step 2: Run setup script

sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/andrewromm/aviatx_setup/master/setup.sh)"


## Step 3: Run PostgreSql setup and restore db

sudo --login --user=postgres

pg_restore -U postgres -Ft -d aviatx < aviatx.tar


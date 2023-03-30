# Setup process

## Step 1: Create ssh key
Note: without passphrase

l
cat /srv/aviatx/ssh/aviatx_rsa.pub

## Step 2: Run setup script

sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/andrewromm/aviatx_setup/master/setup.sh)"


## Step 3: Run PostgreSql setup and restore db

sudo --login --user=postgres

pg_restore -U postgres -Ft -d aviatx < aviatx.tar


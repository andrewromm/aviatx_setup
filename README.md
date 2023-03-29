# Setup

curl -s https://raw.githubusercontent.com/andrewromm/aviatx_setup/master/setup.sh | sudo bash 

# Restore DB

sudo --login --user=postgres

DROP DATABASE aviatx;

pg_restore -U postgres -Ft -d aviatx < aviatx.tar
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

# Остановка всех контейнеров

docker stop $(docker ps -q)

# Удаление всех контейнеров

docker rm $(docker ps -a -q)

# Удаление всех образов

docker rmi $(docker images -q)

# Удаление всех томов

docker volume rm $(docker volume ls -q)

# Удаление всех пользовательских сетей (опционально)

docker network rm $(docker network ls -q)

<!-- CRgAAAAA8J8aM8APA53hnvPIXp0NLN7phueVNvu4 -->

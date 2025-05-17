#!/bin/bash

# ===========================
# Этап 1. Настройка
# ===========================

apt update
apt install -y postgresql
su - postgres

# Тут мб IP поменять на тот, что у контейнера слейва
echo 'host replication postgres 172.27.0.2/32 md5' >> /etc/postgresql/14/main/pg_hba.conf 
echo 'host all all 172.27.0.1/32 md5' >> /etc/postgresql/14/main/pg_hba.conf 
cat >> /etc/postgresql/14/main/postgresql.conf <<EOF
listen_addresses = 'localhost, 172.27.0.3'
wal_level = hot_standby
archive_mode = on
archive_command = 'cd .'
max_wal_senders = 2
hot_standby = on
EOF

pg_ctlcluster 14 main reload
service postgresql restart

# ===========================
# Этап 2.1. Подготовка данных
# ===========================

psql -c "CREATE TABLE test_table1 (id SERIAL PRIMARY KEY, name text NOT NULL, age
INT);"
psql -c "CREATE TABLE test_table2 (id SERIAL PRIMARY KEY, name text NOT NULL, age
INT);"
psql -c "INSERT INTO test_table1 (name, age) VALUES ('Egor', 17), ('Faxri', 18), ('Diana',
17), ('Petr', 0), ('Vladimir', 27);"
psql -c "INSERT INTO test_table1 (name, age) VALUES ('kkk', 3), ('aaa', 76), ('bbb', 23),
('dd', 12), ('Egor', 2);"
psql -c "INSERT INTO test_table2 (name, age) VALUES ('kkk', 3), ('aaa', 76), ('bbb', 23),
('dd', 12), ('Egor', 2);"

# ===========================
# Этап 2.2. Сбой
# ===========================

# Это всё раньше, чем у слейва вводить
mkdir -p /mnt/pgdata_new
mount -t tmpfs -o size=1G tmpfs /mnt/pgdata_new

pg_ctlcluster 14 main stop

rsync -av /var/lib/postgresql/14/main/ /mnt/pgdata_new/
# cp -r /mnt/pgdata_new/main/* /mnt/pgdata_new/
chown -R postgres:postgres /mnt/pgdata_new/
chmod -R 700 /mnt/pgdata_new/

sed -i "s|data_directory = .*|data_directory = '/mnt/pgdata_new'|" /etc/postgresql/14/main/postgresql.conf

pg_ctlcluster 14 main start

dd if=/dev/zero of=/mnt/pgdata_new/fillfile bs=1M count=1000

cat /var/log/postgresql/postgresql-14-main.log | grep -i "disk full\|space\|no space\|error"

pg_ctlcluster 14 main stop

# ===========================
# Этап 3
# ===========================

rm /mnt/pgdata_new/fillfile

pg_ctlcluster 14 main stop

rm -rf /mnt/pgdata_new/*

# Тут поднять кластер на slave не забыть
pg_basebackup -P -R -X stream -c fast -h 172.27.0.2 -U postgres -D /mnt/pgdata_new

chown -R postgres:postgres /mnt/pgdata_new
chmod 700 /mnt/pgdata_new

touch /mnt/pgdata_new/standby.signal

cat >> /etc/postgresql/14/main/postgresql.conf <<EOF
primary_conninfo = 'host=172.27.0.2 port=5432 user=postgres password=postgres'
EOF

pg_ctlcluster 14 main start
pg_ctlcluster 14 main promote

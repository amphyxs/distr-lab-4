#!/bin/bash

# ===========================
# Этап 1. Настройка
# ===========================

apt update
apt install -y postgresql
su - postgres

service postgresql stop

echo 'host replication postgres 172.27.0.3/32 md5' >> /etc/postgresql/14/main/pg_hba.conf
cat >> /etc/postgresql/14/main/postgresql.conf <<EOF
listen_addresses = 'localhost, 172.27.0.2'
wal_level = hot_standby
archive_mode = on
archive_command = 'cd .'
max_wal_senders = 2
hot_standby = on
EOF

rm -rf ~/14/main/
mkdir ~/14/main/
chmod go-rwx ~/14/main/

# Это после того, как у хозяина всё готово
pg_basebackup -P -R -X stream -c fast -h 172.27.0.3 -U postgres -D ~/14/main

service postgresql start

# ===========================
# Этап 2.1. Подготовка данных
# ===========================

# Тут чекать, когда мастер себе данные зафигачит
# assert replication
psql -c "SELECT sender_host, status FROM pg_stat_wal_receiver;"
# assert tables
psql -c "\dt;"
# assert data
psql -c "SELECT * FROM test_table1;"
# assert ERROR:  cannot execute CREATE TABLE in a read-only transaction
psql -c "CREATE TABLE test_table3 (id SERIAL PRIMARY KEY, name text NOT NULL, age
INT);"

# ===========================
# Этап 2.2. Сбой
# ===========================

# Это после того, как сделаем сбой на хозяине
su - postgres
pg_ctlcluster 14 main promote

# assert false
psql -U postgres -c "SELECT pg_is_in_recovery();"

echo 'host all all 172.27.0.1/32 md5' >> /etc/postgresql/14/main/pg_hba.conf
service postgresql restart

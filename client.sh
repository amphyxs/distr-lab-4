#!/bin/bash

# ===========================
# Этап 2.1. Подготовка
# ===========================

psql -h localhost -p 5433 -U postgres -d postgres -c "SELECT * FROM test_table1;"
psql -h localhost -p 5433 -U postgres -d postgres -c "INSERT INTO test_table1 (name, age) VALUES ('Client test', 1), ('Client test', 1), ('Client test', 1);"
psql -h localhost -p 5433 -U postgres -d postgres -c "SELECT * FROM test_table1;"

# ===========================
# Этап 2.2. Сбой
# ===========================

psql -h localhost -p 5434 -U postgres -d postgres -c "SELECT * FROM test_table1;"
psql -h localhost -p 5434 -U postgres -d postgres -c "INSERT INTO test_table1 (name, age) VALUES ('Client test after failover', 1);"

# ===========================
# Этап 3
# ===========================

psql -h localhost -p 5433 -U postgres -d postgres -c "SELECT * FROM test_table1;"
psql -h localhost -p 5434 -U postgres -d postgres -c "SELECT * FROM test_table1;"
psql -h localhost -p 5433 -U postgres -d postgres -c "INSERT INTO test_table1 (name, age) VALUES ('Client test after recovery', 1);"
psql -h localhost -p 5433 -U postgres -d postgres -c "SELECT * FROM test_table1;"
psql -h localhost -p 5434 -U postgres -d postgres -c "SELECT * FROM test_table1;"

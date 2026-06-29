# PostgreSQL Replication Setup (Master → Replica)

## 1. Install PostgreSQL

Install PostgreSQL on **both** primary and replica servers:

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib -y
```

---

## 2. Configure the Primary Server

### 2.1 Edit PostgreSQL configuration

```bash
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_level = replica/wal_level = replica/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#hot_standby = on/hot_standby = on/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_keep_size = 0/wal_keep_size = 512/g" /etc/postgresql/16/main/postgresql.conf
```

### 2.2 Allow replication connections from replica servers

```bash
echo "host    replication     all             192.168.26.4/32            md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
echo "host    replication     all             192.168.26.5/32            md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
```

### 2.3 Restart PostgreSQL

```bash
sudo systemctl restart postgresql
```

### 2.4 Create a replication user

```bash
sudo -u postgres psql -c "CREATE ROLE replication_user WITH REPLICATION PASSWORD 'Test@123' LOGIN;"
```

---

## 3. Set Up Replication on the Replica Server

### 3.1 Stop PostgreSQL service

```bash
sudo systemctl stop postgresql
```

### 3.2 Clean and prepare the data directory

```bash
# Create cluster on replica server (if needed)
# sudo pg_createcluster 16 main --start-conf=auto

# Remove existing data directory on the replica server
# sudo rm -rf /var/lib/postgresql/16/main/*
# sudo pg_dropcluster --stop 16 main
# sudo mkdir -p /var/lib/postgresql/16/main

sudo chown -R root:root /var/lib/postgresql/16/main
sudo rm -rf /var/lib/postgresql/16/main/*
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
```

### 3.3 Use `pg_basebackup` to copy data from the primary server

```bash
sudo -u postgres pg_basebackup -h 192.168.26.3 -D /var/lib/postgresql/16/main -U replication_user -v -P --wal-method=stream -R
```

### 3.4 Start PostgreSQL and verify replication

```bash
sudo systemctl start postgresql

# Check replication status on the replica server
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

> **Note:** The following recovery configuration is an alternative approach (commented out in the original script):
> ```bash
> echo "standby_mode = 'on'" | sudo tee /var/lib/postgresql/16/main/recovery.conf
> echo "primary_conninfo = 'host=192.168.26.3 port=5432 user=replication_user password=Test@123'" | sudo tee -a /var/lib/postgresql/16/main/recovery.conf
> ```

---

## 4. Test Replication

Insert data into the primary server (master) and check if it appears on the replica server (standby).

### 4.1 Create database and insert test data (on master)

```bash
sudo -u postgres psql -c "create database labdb;"

sudo -u postgres psql -d labdb -c "
CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    message TEXT,
    created_at TIMESTAMP DEFAULT now()
);
INSERT INTO test_replication(message) VALUES ('Hello from master');
SELECT * FROM test_replication;
"
```

### 4.2 Verify data on the replica server

```bash
sudo -u postgres psql -d labdb -c "SELECT * FROM test_replication;"
```

---

## 5. Allow Remote Access to PostgreSQL

### 5.1 Edit configuration for remote connections

```bash
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
```

### 5.2 Allow connections from any IP (for testing purposes)

```bash
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
```

### 5.3 Restart PostgreSQL

```bash
sudo systemctl restart postgresql
```

### 5.4 Verify port 5432 is listening

```bash
sudo netstat -tuln | grep 5432
```

---

## 6. Create User for DBeaver

### 6.1 Create user and grant privileges

```sql
-- Connect to psql
-- sudo -u postgres psql

CREATE USER dbeaver_user WITH PASSWORD 'Test@123';
GRANT ALL PRIVILEGES ON DATABASE labdb TO dbeaver_user;
\c labdb
GRANT ALL ON SCHEMA public TO dbeaver_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dbeaver_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO dbeaver_user;
```

### 6.2 Test connectivity from client machine

```bash
nc -zv 192.168.26.3 5432
```

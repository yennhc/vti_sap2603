# PostgreSQL Replication Lab — Master → Replica

**Nhân bản dữ liệu Master → Replica** · Streaming replication setup
*Ubuntu 26.04 · PostgreSQL 16 · LAN 192.168.100.0/24 · 1 Master + 2 Replica + 1 Client*

---

## 🎯 Mục tiêu · Objectives

- Cài đặt PostgreSQL trên 3 máy chủ Ubuntu. — *Install PostgreSQL on three Ubuntu servers.*
- Cấu hình **streaming replication** từ Master sang 2 Replica. — *Configure streaming replication from the primary to two standbys.*
- Kiểm tra dữ liệu tự đồng bộ & mở kết nối từ xa cho DBeaver. — *Verify auto-sync and enable remote access for DBeaver.*

---

## Sơ đồ máy chủ · Machines

| Vai trò / Role | Hostname | IP | Ghi chú / Notes |
|---|---|---|---|
| **Primary / Master** | `pg-master` | `192.168.100.3` | Nhận ghi · gửi WAL / accepts writes, ships WAL |
| **Replica 1 / Standby** | `pg-replica-1` | `192.168.100.4` | Chỉ đọc / read-only standby |
| **Replica 2 / Standby** | `pg-replica-2` | `192.168.100.5` | Chỉ đọc / read-only standby |
| **Client / DBeaver** | `client` | `192.168.100.10` | Kết nối tới :5432 / GUI client |

---

## Sơ đồ mạng · Network diagram

Master gửi luồng WAL tới hai Replica; Client truy vấn qua cổng 5432.
*The primary streams WAL to both replicas; the client queries over port 5432.*

```
        ┌─────────────────────┐         WAL stream        ┌─────────────────────┐
        │  PRIMARY · MASTER   │ ───────────────────────►  │ REPLICA 1 · STANDBY │
        │  pg-master          │ ─────────────┐            │  pg-replica-1       │
        │  192.168.100.3  R/W │              │            │  192.168.100.4  RO  │
        └──────────┬──────────┘              │            └──────────┬──────────┘
                   │                          │ WAL stream            │
                   │            ┌─────────────▼─────────────┐         │
                   └────────────┤  LAN SWITCH               ├─────────┘
                   ┌────────────┤  192.168.100.0/24         ├─────────┐
                   │            └─────────────▲─────────────┘         │
        ┌──────────┴──────────┐    SQL :5432  │            ┌──────────┴──────────┐
        │  CLIENT · DBEAVER   │ ──────────────┘            │ REPLICA 2 · STANDBY │
        │  client             │                            │  pg-replica-2       │
        │  192.168.100.10     │                            │  192.168.100.5  RO  │
        └─────────────────────┘                            └─────────────────────┘

  ───►  WAL replication stream        ────  LAN link
```

> ⚠️ **Trước khi bắt đầu · Before you start.** Bài lab dùng PostgreSQL **16** (đường dẫn `/etc/postgresql/16/main`).
> Trên Ubuntu 26.04 hãy kiểm tra phiên bản thực tế bằng `ls /etc/postgresql/` và thay số **16** trong mọi lệnh cho khớp.
> *PostgreSQL 16 paths are assumed — run `ls /etc/postgresql/` and replace 16 with your installed major version everywhere.*

---

## 1. Cài đặt PostgreSQL · Install PostgreSQL

> **Chạy trên cả 3 máy / Run on all servers** (Master `.3` + Replica `.4` `.5`)

Cập nhật hệ thống và cài PostgreSQL trên Master và cả hai Replica.
*Update and install the same package set on the primary and both replicas.*

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib -y
```

**Màn hình minh hoạ / Sample output:**

```text
Reading package lists... Done
The following NEW packages will be installed:
  postgresql postgresql-16 postgresql-client-16 postgresql-contrib
Setting up postgresql-16 (16.x) ...
Creating new PostgreSQL cluster 16/main ...
✓ postgresql.service is now active (running)
```

---

## 2. Cấu hình máy chủ Master · Configure the primary

> **Chỉ trên Master (`.3`) / primary only**

### 2.1 — Sửa `postgresql.conf`

Bật lắng nghe mọi địa chỉ và mức WAL `replica`.
*Enable network listening and replica-level WAL.*

```bash
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_level = replica/wal_level = replica/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#hot_standby = on/hot_standby = on/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_keep_size = 0/wal_keep_size = 512/g" /etc/postgresql/16/main/postgresql.conf
```

### 2.2 — Cho phép Replica kết nối (`pg_hba.conf`)

Mở quyền replication cho IP của hai Replica.
*Allow replication from each replica's IP.*

```bash
# Replica 1
echo "host    replication     all     192.168.100.4/32     md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
# Replica 2
echo "host    replication     all     192.168.100.5/32     md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
```

### 2.3 — Khởi động lại & 2.4 — Tạo user replication

Áp dụng cấu hình rồi tạo role `replication_user`.
*Restart, then create the replication role.*

```bash
sudo systemctl restart postgresql

sudo -u postgres psql -c "CREATE ROLE replication_user WITH REPLICATION PASSWORD 'Test@123' LOGIN;"
```

**Màn hình minh hoạ / Sample output:**

```text
CREATE ROLE
# role 'replication_user' sẵn sàng nhận kết nối WAL
```

---

## 3. Thiết lập Replica · Set up replication

> **Lặp lại trên từng Replica (`192.168.100.4` và `192.168.100.5`) / repeat on each replica**

### 3.1 + 3.2 — Dừng dịch vụ & dọn thư mục dữ liệu

Xoá data cũ để chuẩn bị nhận bản sao từ Master.
*Stop the service and empty the data directory.*

```bash
sudo systemctl stop postgresql

sudo chown -R root:root /var/lib/postgresql/16/main
sudo rm -rf /var/lib/postgresql/16/main/*
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
```

### 3.3 — Sao chép dữ liệu bằng `pg_basebackup`

Kéo toàn bộ dữ liệu từ Master và tự tạo cấu hình standby (cờ `-R`).
*Clone from the primary; `-R` writes standby config automatically.*

```bash
sudo -u postgres pg_basebackup -h 192.168.100.3 -D /var/lib/postgresql/16/main \
     -U replication_user -v -P --wal-method=stream -R
```

**Màn hình minh hoạ / Sample output:**

```text
pg_basebackup: initiating base backup, waiting for checkpoint
pg_basebackup: starting background WAL receiver
 31864/31864 kB (100%), 1/1 tablespace
pg_basebackup: write-ahead log end point: 0/A000100
✓ pg_basebackup: base backup completed
```

### 3.4 — Khởi động & kiểm tra replication

Chạy lệnh kiểm tra **trên Master** — phải thấy cả hai Replica đang `streaming`.
*Start the replica, then check `pg_stat_replication` on the primary.*

```bash
# trên Replica
sudo systemctl start postgresql

# trên Master — xem trạng thái
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

**Màn hình minh hoạ / Sample output:**

```text
 client_addr   | state     | sync_state
---------------+-----------+-----------
 192.168.100.4 | streaming | async
 192.168.100.5 | streaming | async
(2 rows)   ✓ cả hai Replica đang đồng bộ
```

> ℹ️ **Cách thay thế (không bắt buộc).** Bản PostgreSQL cũ dùng `recovery.conf`; PG 12+ đã thay bằng cờ `-R` của
> `pg_basebackup` (tự tạo `standby.signal` + `primary_conninfo`).
> *Legacy `recovery.conf` is replaced by the `-R` flag on modern PostgreSQL:*
> ```bash
> echo "standby_mode = 'on'" | sudo tee /var/lib/postgresql/16/main/recovery.conf
> echo "primary_conninfo = 'host=192.168.100.3 port=5432 user=replication_user password=Test@123'" | sudo tee -a /var/lib/postgresql/16/main/recovery.conf
> ```

---

## 4. Kiểm tra đồng bộ · Test replication

> **Ghi ở Master → đọc ở Replica**

### 4.1 — Tạo dữ liệu trên Master

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

### 4.2 — Đọc dữ liệu trên Replica

```bash
sudo -u postgres psql -d labdb -c "SELECT * FROM test_replication;"
```

**Màn hình minh hoạ / Sample output:**

```text
 id |     message       |         created_at
----+-------------------+----------------------------
  1 | Hello from master | 2026-06-29 09:14:22.108
(1 row)   ✓ dữ liệu đã tự xuất hiện trên Replica!
```

---

## 5. Mở kết nối từ xa · Allow remote access

> **Cho client trong LAN / on all servers**

Cho phép kết nối từ client (DBeaver).
*Open PostgreSQL to clients on the LAN, then confirm it is listening.*

> ⚠️ `0.0.0.0/0` mở cho mọi IP — chỉ dùng trong môi trường lab.
> *Use this only in an isolated lab; restrict the CIDR in production.*

```bash
# 5.1 lắng nghe mọi địa chỉ
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
# 5.2 cho phép mọi IP (chỉ dùng cho lab)
echo "host    all     all     0.0.0.0/0     md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
# 5.3 khởi động lại  &  5.4 kiểm tra cổng
sudo systemctl restart postgresql
sudo netstat -tuln | grep 5432
```

**Màn hình minh hoạ / Sample output:**

```text
tcp    0  0 0.0.0.0:5432   0.0.0.0:*   LISTEN
tcp6   0  0 :::5432        :::*        LISTEN
```

---

## 6. Tạo user cho DBeaver · Create a DBeaver user

> **Trên Master (`.3`), kiểm tra từ Client (`.10`)**

### 6.1 — Tạo user & cấp quyền (SQL)

Chạy trong psql: `sudo -u postgres psql` rồi nhập các lệnh sau.
*Run inside psql on the master.*

```sql
CREATE USER dbeaver_user WITH PASSWORD 'Test@123';
GRANT ALL PRIVILEGES ON DATABASE labdb TO dbeaver_user;
\c labdb
GRANT ALL ON SCHEMA public TO dbeaver_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dbeaver_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO dbeaver_user;
```

### 6.2 — Kiểm tra kết nối từ máy Client

```bash
nc -zv 192.168.100.3 5432
```

**Màn hình minh hoạ / Sample output:**

```text
Connection to 192.168.100.3 5432 port [tcp/postgresql] succeeded!
# Mở DBeaver → New Connection → PostgreSQL
# Host 192.168.100.3 · Port 5432 · DB labdb · User dbeaver_user
```

> ✓ **Mẹo:** kết nối DBeaver tới Replica (`.4`/`.5`) là **read-only** — dùng để phân tải truy vấn đọc.
> *Point DBeaver at a replica for read-only query offloading.*

---

*PostgreSQL Replication Lab · Ubuntu 26.04 · PostgreSQL 16 · 192.168.100.0/24*

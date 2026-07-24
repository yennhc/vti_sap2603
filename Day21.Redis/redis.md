
# Redis lab

## IP Plan
```
Server          IP Address              Vai trò
nginx-web       192.168.100.10PI        Nginx Reverse Proxy / Web Server 
redis-master    192.168.100.20          Redis Master + MySQL 
redis-replica   192.168.100.30          Redis Replica 
```

## 1. Build Nginx proxy + Web server

```bash
# Cập nhật package list và nâng cấp hệ thống 
sudo apt update && sudo apt upgrade -y 

# Cài các công cụ cần thiết 
sudo apt install -y curl wget net-tools vim ufw 
```

### 1.1. Config ufw on nginx

```bash
# HTTP sudo ufw allow 443/tcp   
sudo ufw allow OpenSSH 
sudo ufw allow 80/tcp

# HTTPS 
sudo ufw enable 
sudo ufw status
```

### 1.2. Install Nginx

```bash
# Cài đặt Nginx 
sudo apt install -y nginx  

# Khởi động và enable service 
sudo systemctl start nginx sudo systemctl enable nginx  

# Kiểm tra trạng thái 
sudo systemctl status nginx 
```

### 1.3. Cấu Hình Nginx Reverse Proxy 

```bash
# Tạo thư mục và file test
mkdir -p /var/www/backend
echo "<h1>Backend App - Port 8080</h1><p>Reverse Proxy hoạt động!</p>" | sudo tee /var/www/backend/index.html

# Chạy Python HTTP server tại port 8080
cd /var/www/backend
sudo python3 -m http.server 8080

```


```bash
sudo vim /etc/nginx/sites-available/lab-app 
```
#### Nội dung file cấu hình: 
```bash
upstream backend {
    server 127.0.0.1:8080;   # backend app (nếu có)
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

upstream backend {
    server 127.0.0.1:8080;
}

server {
    listen 80 default_server;
    server_name _;

    access_log /var/log/nginx/lab-app.access.log;
    error_log  /var/log/nginx/lab-app.error.log;

    location / {
        proxy_pass         http://backend;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}

```

```bash
# Kích hoạt site và kiểm tra cấu hình 
sudo ln -s /etc/nginx/sites-available/lab-app /etc/nginx/sites-enabled/
sudo nginx -t

# Reload Nginx 
sudo systemctl reload nginx
```

## 2. Build Redis Server

### 2.1. Config firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow from 192.168.100.10 to any port 6379   # Nginx -> Redis 
sudo ufw allow from 192.168.100.30 to any port 6379   # Replica -> Master
sudo ufw allow from 192.168.100.10 to any port 3306   # Nginx -> MySQL
sudo ufw enable 
sudo ufw status
```

### 2.2. Install Redis Master Server

```bash
# Cài đặt Redis Server  
sudo apt install -y redis-server    
```

### 2.3. Config Redis Server

```bash
# Backup file cấu hình gốc 
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak 

# Chỉnh sửa file cấu hình 
sudo vim /etc/redis/redis.conf

#### Nội dung file cấu hình:#

# Lắng nghe trên tất cả interface (hoặc chỉ IP nội bộ) 
bind 0.0.0.0 

# Tắt protected mode để cho phép kết nối từ xa 
protected-mode no 

# Đặt password cho Redis (khuyến nghị) 
requirepass Demo!@##@!123

# Kích hoạt AOF persistence 
appendonly yes
appendfilename "appendonly.aof" 

# RDB snapshot 
save 900 1 
save 300 10 
save 60 10000 

# Tên log file 
logfile /var/log/redis/redis-server.log 

# Max memory policy 
maxmemory 512mb 
maxmemory-policy allkeys-lru 

```

```bash
# Khởi động lại Redis 
sudo systemctl restart redis-server
sudo systemctl enable redis-server 

# Kiểm tra
redis-cli -a 'Demo!@##@!123' ping 
# Expected: PONG 

```

## 3. Build Redis Replica Server

### 3.1. Config firewall

```bash
sudo ufw allow OpenSSH 
sudo ufw allow from 192.168.100.10 to any port 6379   # Nginx -> Replica 
sudo ufw enable 
sudo ufw status
```

### 3.2. Install Redis Replica Server

```bash

# Cài đặt Redis Server  
sudo apt install -y redis-server    

#Backup configuration
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak 

# Edit configuration
sudo vim /etc/redis/redis.conf 

#### Nội dung file cấu hình:

# Bind all interfaces 
bind 0.0.0.0 
replicaof 192.168.100.20 6379
protected-mode no 
masterauth Demo!@##@!123
requirepass Demo!@##@!123 

# Replica chỉ đọc 
replica-read-only yes 

# Log 
logfile /var/log/redis/redis-server.log 

```

```bash
# Khởi động lại Redis Replica 
sudo systemctl restart redis-server 
sudo systemctl enable redis-server 

# Kiểm tra 
redis-cli -a 'Demo!@##@!123' ping 
# Expected: PONG
```

## 4. Verify replication

```bash
# Trên máy MASTER (192.168.100.20) 
redis-cli -a 'Demo!@##@!123' info replication
```

## 5. Install mysql server

```bash
# Cài đặt MySQL 
sudo apt install -y mysql-server

# Khởi động MySQL 
sudo systemctl start mysql
sudo systemctl enable mysql 

# Chạy script bảo mật 
sudo mysql_secure_installation 

# Trả lời: Set root password? Y 
#         Remove anonymous users? Y 
#         Disallow root login remotely? Y 
#         Remove test database and access to it? Y 
#         Reload privilege tables now? Y 

##### Tạo Database và User ####

# Đăng nhập vào MySQL với quyền root 
sudo mysql -u root -p 

#Thực hiện trong MySQL console: 
#-- Tạo database cho ứng dụng 
CREATE DATABASE labapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; 

#-- Tạo user cho ứng dụng
CREATE USER 'labuser'@'192.168.100.10' IDENTIFIED BY 'DbPassword123!';
CREATE USER 'labuser'@'localhost'    IDENTIFIED BY 'DbPassword123!'; 

#-- Cấp quyền 
GRANT ALL PRIVILEGES ON labapp.* TO 'labuser'@'192.168.100.10';
GRANT ALL PRIVILEGES ON labapp.* TO 'labuser'@'localhost';
FLUSH PRIVILEGES; 

#-- Kiểm tra 
SHOW DATABASES; 
SELECT user, host FROM mysql.user;
EXIT; 

```

### Allow mysql remote access

```bash
sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf 

# Thay dòng:
# bind-address = 127.0.0.1

# Thành (chỉ cho phép LAN): 
bind-address = 192.168.100.20 

sudo systemctl restart mysql 
sudo systemctl status mysql 

```

## 6. Test connection

### Từ máy Nginx, kiểm tra kết nối đến cả 2 Redis node: 

```bash
# Cài redis-tools trên máy Nginx 
sudo apt install -y redis-tools 

# Kết nối đến Redis Master
redis-cli -h 192.168.100.20 -p 6379 -a 'Demo!@##@!123' ping
# Expected: PONG 

# Kết nối đến Redis Replica 
redis-cli -h 192.168.100.30 -p 6379 -a 'Demo!@##@!123' ping
# Expected: PONG 
```

```bash
#Test Replication Thực Tế 

# --- Trên máy MASTER --- 
redis-cli -h 192.168.100.20 -a 'Demo!@##@!123' SET testkey "Hello from Master" 

# --- Trên máy REPLICA --- 
redis-cli -h 192.168.100.30 -a 'Demo!@##@!123' GET testkey 
# Expected: Hello from Master 

# Thử ghi trên Replica (phải thất bại) 
redis-cli -h 192.168.100.30 -a 'Demo!@##@!123' SET newkey "test" 
# Expected: READONLY You can't write against a read only replica. 

```

```bash
### Test Kết Nối MySQL Từ Nginx 

# Cài MySQL client trên máy Nginx 
sudo apt install -y mysql-client 

# Kết nối đến MySQL 
mysql -h 192.168.100.20 -u labuser -p labapp 

```

```bash
### Test Nginx 

# Kiểm tra từ bên ngoài 
curl -I http://192.168.100.10 
# Expected: HTTP/1.1 200 OK 

# Kiểm tra log 
sudo tail -f /var/log/nginx/lab-app.access.log 


```
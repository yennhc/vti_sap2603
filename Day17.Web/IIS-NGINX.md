**System Administrator / Infrastructure Engineer**
## Lab 1: Cài đặt Web Server cơ bản

### Mục tiêu

* Hiểu cách hoạt động của HTTP/HTTPS
* Deploy website tĩnh

### Nginx (Ubuntu)

```bash
sudo apt update
sudo apt install nginx -y

systemctl status nginx
```

Tạo website:

```bash
mkdir -p /var/www/lab1

echo "<h1>Hello Nginx</h1>" > /var/www/lab1/index.html
```

Virtual Host:

```bash
sudo nano /etc/nginx/sites-available/lab1
```

```nginx
server {
    listen 80;
    server_name nginx.lab.local;

    root /var/www/lab1;
    index index.html;
}
```

Enable:

```bash
ln -s /etc/nginx/sites-available/lab1 \
/etc/nginx/sites-enabled/

nginx -t
systemctl reload nginx
```

---

### IIS (Windows Server)

* Server Manager
* Add Roles and Features
* Install **Web Server (IIS)**

Tạo website:

```powershell
mkdir C:\Web\Lab1
```

File:

```html
<h1>Hello IIS</h1>
```

IIS Manager:

```
Sites
 └─ Add Website
```

* Site Name: Lab1
* Physical Path: C:\Web\Lab1
* Port: 80

Kiểm tra:

```
http://server-ip
```

---

# Lab 2: Virtual Host / Multiple Websites

### Mục tiêu

Một server chạy nhiều website.

Ví dụ:

```
web01
├── hr.lab.local
├── finance.lab.local
└── student.lab.local
```

### Nginx

```nginx
server {
 listen 80;
 server_name hr.lab.local;
 root /var/www/hr;
}
```

```nginx
server {
 listen 80;
 server_name finance.lab.local;
 root /var/www/finance;
}
```

### IIS

Tạo 3 website:

```
HR
Finance
Student
```

Binding:

```
hr.lab.local
finance.lab.local
student.lab.local
```

---

# Lab 3: HTTPS với SSL Certificate

### Mục tiêu

Hiểu TLS và certificate.

### Nginx

Generate cert:

```bash
openssl req -x509 \
-newkey rsa:2048 \
-keyout key.pem \
-out cert.pem \
-days 365 \
-nodes
```

Configure:

```nginx
server {
 listen 443 ssl;

 ssl_certificate cert.pem;
 ssl_certificate_key key.pem;
}
```

---

### IIS

IIS Manager

```
Server Certificates
```

Import certificate.

Binding:

```
https
port 443
```

Kiểm tra:

```
https://web.lab.local
```

---

# Lab 4: Reverse Proxy

### Mục tiêu

Nginx/IIS đứng trước ứng dụng backend.

Sơ đồ:

```text
Client
   |
Nginx/IIS
   |
Backend Application
(port 3000)
```

Ví dụ NodeJS:

```bash
node app.js
```

port:

```
3000
```

Nginx:

```nginx
location / {
 proxy_pass http://127.0.0.1:3000;
}
```

Thử với:

* NodeJS
* Flask
* ASP.NET

---

# Lab 5: Load Balancing

### Mục tiêu

Một website chạy trên nhiều server.

```text
          Nginx
        /       \
      App1     App2
```

Nginx:

```nginx
upstream backend {
    server 192.168.1.101;
    server 192.168.1.102;
}

server {
    location / {
        proxy_pass http://backend;
    }
}
```

Kiểm tra:

```bash
curl web.lab.local
```

---

# Lab 6: Authentication

### Nginx Basic Auth

Tạo user:

```bash
apt install apache2-utils

htpasswd -c /etc/nginx/.htpasswd admin
```

Config:

```nginx
auth_basic "Protected";
auth_basic_user_file /etc/nginx/.htpasswd;
```

---

### IIS Windows Authentication

Enable:

```
Windows Authentication
```

Disable:

```
Anonymous Authentication
```

Thử đăng nhập bằng tài khoản AD.

---

# Lab 7: IIS + Active Directory

### Mục tiêu

SSO với AD.

Sơ đồ:

```text
User
  |
 Active Directory
  |
 IIS
```

Thực hiện:

* Domain Join Windows Server
* Enable Windows Authentication
* Test Kerberos Authentication

Kiểm tra:

```powershell
klist
```

---

# Lab 8: Logging và Monitoring

### Nginx

Access log:

```bash
tail -f /var/log/nginx/access.log
```

Error log:

```bash
tail -f /var/log/nginx/error.log
```

### IIS

Log:

```
C:\inetpub\logs\LogFiles
```

Thu thập bằng:

* Zabbix Agent
* Elastic Agent
* Winlogbeat
* Filebeat

---

# Lab 9: Nginx + Grafana + InfluxDB

Liên quan đúng hướng bạn đang học.

Sơ đồ:

```text
IoT Device
    |
 MQTT
    |
 Node-RED
    |
 InfluxDB
    |
 Grafana
    |
 Nginx Reverse Proxy
```

Nginx:

```nginx
server {
 listen 80;

 location / {
     proxy_pass http://127.0.0.1:3000;
 }
}
```

Mục tiêu:

* Publish Grafana qua Nginx
* HTTPS
* Authentication

---

# Lab 10: Web Farm Enterprise

Sơ đồ hoàn chỉnh:

```text
             HAProxy
                |
      -------------------
      |                 |
    Nginx01          Nginx02
      |                 |
      -------------------
                |
        Application Servers
                |
             Database
```

Thực hành:

* HAProxy
* Nginx Reverse Proxy
* SSL Offloading
* Load Balancing
* Health Check
* Failover

---

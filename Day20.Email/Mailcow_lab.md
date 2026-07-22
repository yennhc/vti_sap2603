LAB Mailcow hoàn chỉnh trên Ubuntu 24.04

Lab này giúp bạn học:

* SMTP
* IMAP
* POP3
* SPF
* DKIM
* DMARC
* Mailbox
* Mail Queue
* Anti-Spam
* Webmail
* Mail Flow

⸻

Mô hình Lab

                 Internet (Optional)
                       |
                192.168.100.0/24
                       |
          +--------------------------+
          | Ubuntu 24.04 Mailcow     |
          | mail.lab.local           |
          | 192.168.100.10           |
          +--------------------------+
                 |          |
         SMTP 25 |          | HTTPS 443
                 |          |
        +--------------------------+
        | Windows 11 Client        |
        | Outlook / Browser        |
        | 192.168.100.20           |
        +--------------------------+

⸻

## Yêu cầu VM

```bash
Mail Server

OS      : Ubuntu Server 24.04
CPU     : 2 vCPU
RAM     : 6-8 GB
Disk    : 50 GB
IP      : 192.168.100.10
Hostname: mail
Domain  : lab.local

Client

Windows 11
192.168.100.20
```

⸻

## Bước 1: Cập nhật Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

## Bước 2: Đặt hostname

```bash
sudo hostnamectl set-hostname mail
```

Kiểm tra:
```bash
hostname
```

## Bước 3: Cấu hình hosts

```bash
sudo nano /etc/hosts

Thêm:

127.0.0.1 localhost
192.168.100.10 mail.vti.lab mail
```

## Bước 4: Cài Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
```

Kiểm tra:

```bash
docker --version
```

⸻

## Bước 5: Cài Docker Compose

```bash
sudo apt install docker-compose-plugin -y
```

Kiểm tra:

```bash
docker compose version
```

⸻

## Bước 6: Download Mailcow

```bash
cd /opt
sudo git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized
```

⸻

## Bước 7: Tạo file cấu hình

```bash
sudo ./generate_config.sh

Nhập:

mail.vti.lab

Tạo file:

mailcow.conf

```

⸻

## Bước 8: Khởi động Mailcow

```bash
sudo docker compose pull
sudo docker compose up -d

Chờ khoảng:

5-10 phút

```

⸻

## Bước 9: Kiểm tra container

```bash
docker ps

Sẽ thấy:

postfix-mailcow
dovecot-mailcow
rspamd-mailcow
nginx-mailcow
sogo-mailcow
clamd-mailcow
mysql-mailcow
redis-mailcow
```

⸻

## Bước 10: Truy cập Web UI

```bash
Mở trình duyệt:

https://192.168.100.10

hoặc

https://mail.lab.local

```

⸻

## Tài khoản mặc định

```
admin
moohoo

Đổi password ngay lần đầu.

```

⸻

## Bước 11: Tạo Domain

```bash
Mailcow

Configuration
→ Mail Setup
→ Domains
→ Add Domain

Domain:

vti.lab
```

⸻

## Bước 12: Tạo User

```bash
Configuration
→ Mail Setup
→ Mailboxes
→ Add Mailbox

Tạo:

user1@vti.lab
user2@vti.lab

```
⸻

## Bước 13: Test Webmail

```bash

https://mail.lab.local/SOGo

Login:

user1@lab.local

```

⸻

## Bước 14: Gửi mail nội bộ

```bash
User1 gửi:

user1@lab.local

đến

user2@lab.local

Kiểm tra:

Inbox
Sent Items

```

⸻


## Bước 15: Xem Mail Queue

```bash 

Mailcow

System
→ Mail Queue

Hoặc CLI:

docker exec -it postfix-mailcow postqueue -p

```
⸻

## Bước 16: Theo dõi log

```bash

docker logs -f postfix-mailcow
docker logs -f dovecot-mailcow
docker logs -f rspamd-mailcow

```
⸻

## LAB SPF

```bash 

Tạo TXT record:

v=spf1 mx -all

Kiểm tra:

dig TXT lab.local

```

⸻

## LAB DKIM

```bash
Mailcow

Configuration
→ ARC/DKIM Keys

Copy DKIM record.

Tạo DNS:

dkim._domainkey.lab.local

```

⸻


## LAB DMARC

```bash

Tạo:

_dmarc.lab.local

TXT:

v=DMARC1; p=quarantine;

```

⸻


## LAB Anti-Spam

```bash 

Gửi mail:

FREE MONEY
CLICK HERE
WINNER

Xem:

Rspamd Score

```

⸻

## LAB Outlook

```bash

Windows 11

Control Panel
→ Mail
→ Add Account

IMAP:

mail.vti.lab

SMTP:

mail.vti.lab

Port:

IMAP 993
SMTP 587

```

⸻

Bài Lab nâng cao cho System Administrator

Lab 1

2 Domain
------------
company.local
school.local

Tạo user cho mỗi domain.

⸻

Lab 2

Mail Relay

Server A relay qua Server B.

⸻

Lab 3

Mail Gateway

Internet
→ Gateway Mailcow
→ Internal Mail Server

⸻

Lab 4

Active Directory Integration

Mailcow
↔ LDAP
↔ Active Directory

User AD đăng nhập Mailcow.

⸻

Lab 5 (rất giống doanh nghiệp)

HAProxy
     |
+----------+
| Mailcow1 |
+----------+
+----------+
| Mailcow2 |
+----------+

Load Balancing và High Availability.

⸻

Với nền tảng hiện tại của bạn (AD, DNS, Hyper-V/VMware, Exchange/M365), một lab rất thực tế là:

DC01 (AD + DNS)
192.168.100.5
MAIL01 (Mailcow)
192.168.100.10
WIN11-CLIENT
192.168.100.20

Sau đó tích hợp LDAP với AD để người dùng domain đăng nhập Mailcow bằng tài khoản AD. Lab này mô phỏng gần giống môi trường doanh nghiệp thực tế nhất.
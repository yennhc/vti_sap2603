Đúng hướng. Doanh nghiệp thật thường dùng **3 RabbitMQ nodes + Quorum Queue + HAProxy**. RabbitMQ khuyến nghị quorum queues cho queue cần replicated/high availability; cluster 2 node không nên dùng vì dễ mất quorum. ([RabbitMQ][1])

# LAB RabbitMQ Cluster Production-like

## Sơ đồ

```text
Network: 192.168.100.0/24

                 +----------------------+
                 |      HAProxy         |
                 |   192.168.100.9      |
                 | AMQP:5672 / UI:15672 |
                 +----------+-----------+
                            |
        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v
+---------------+   +---------------+   +---------------+
| rabbitmq-01   |   | rabbitmq-02   |   | rabbitmq-03   |
| 192.168.100.10|   | 192.168.100.11|   | 192.168.100.12|
+---------------+   +---------------+   +---------------+

Producer/Consumer connect tới:
192.168.100.9:5672
```

## VM cần chuẩn bị

| VM          |             IP | Vai trò           |
| ----------- | -------------: | ----------------- |
| haproxy     |  192.168.100.9 | Load Balancer     |
| rabbitmq-01 | 192.168.100.10 | RabbitMQ node 1   |
| rabbitmq-02 | 192.168.100.11 | RabbitMQ node 2   |
| rabbitmq-03 | 192.168.100.12 | RabbitMQ node 3   |
| app01       | 192.168.100.20 | Producer/Consumer |

---

# 1. Cấu hình `/etc/hosts`

Trên cả 4 máy RabbitMQ/HAProxy/app:

```bash
sudo nano /etc/hosts
```

Thêm:

```text
192.168.100.9  haproxy
192.168.100.10 rabbitmq-01
192.168.100.11 rabbitmq-02
192.168.100.12 rabbitmq-03
192.168.100.20 app01
```

---

# 2. Cài RabbitMQ trên cả 3 node

Chạy trên `rabbitmq-01`, `rabbitmq-02`, `rabbitmq-03`:

```bash
sudo apt update
sudo apt install rabbitmq-server -y
sudo systemctl enable --now rabbitmq-server
sudo rabbitmq-plugins enable rabbitmq_management
```

---

# 3. Set hostname

Trên node 1:

```bash
sudo hostnamectl set-hostname rabbitmq-01
```

Trên node 2:

```bash
sudo hostnamectl set-hostname rabbitmq-02
```

Trên node 3:

```bash
sudo hostnamectl set-hostname rabbitmq-03
```

Reboot 3 node:

```bash
sudo reboot
```

---

# 4. Đồng bộ Erlang cookie

Trên `rabbitmq-01`:

```bash
sudo cat /var/lib/rabbitmq/.erlang.cookie
```

Copy giá trị đó sang node 2 và node 3:

```bash
sudo systemctl stop rabbitmq-server
sudo nano /var/lib/rabbitmq/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
sudo systemctl start rabbitmq-server
```

---

# 5. Join node 2 và node 3 vào cluster

Trên `rabbitmq-02`:

```bash
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbitmq-01
sudo rabbitmqctl start_app
```

Trên `rabbitmq-03`:

```bash
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbitmq-01
sudo rabbitmqctl start_app
```

Kiểm tra trên node 1:

```bash
sudo rabbitmqctl cluster_status
```

Bạn phải thấy:

```text
rabbit@rabbitmq-01
rabbit@rabbitmq-02
rabbit@rabbitmq-03
```

---

# 6. Tạo admin user

Trên `rabbitmq-01`:

```bash
sudo rabbitmqctl add_user admin Admin@123
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
sudo rabbitmqctl delete_user guest
```

---

# 7. Mở firewall

Trên 3 RabbitMQ node:

```bash
sudo ufw allow 4369/tcp
sudo ufw allow 5672/tcp
sudo ufw allow 15672/tcp
sudo ufw allow 25672/tcp
```

Các port quan trọng:

| Port  | Mục đích                       |
| ----- | ------------------------------ |
| 5672  | App kết nối AMQP               |
| 15672 | Web UI                         |
| 4369  | Erlang port mapper             |
| 25672 | RabbitMQ cluster communication |

---

# 8. Tạo Quorum Queue

Trên `rabbitmq-01`:

```bash
sudo rabbitmqctl set_policy ha-quorum "^school\." \
'{"queue-type":"quorum"}' \
--apply-to queues
```

Tạo exchange:

```bash
sudo rabbitmqadmin declare exchange \
name=school_events \
type=fanout \
durable=true \
-u admin -p Admin@123
```

Tạo queue:

```bash
sudo rabbitmqadmin declare queue \
name=school.email \
durable=true \
arguments='{"x-queue-type":"quorum"}' \
-u admin -p Admin@123

sudo rabbitmqadmin declare queue \
name=school.ad \
durable=true \
arguments='{"x-queue-type":"quorum"}' \
-u admin -p Admin@123

sudo rabbitmqadmin declare queue \
name=school.audit \
durable=true \
arguments='{"x-queue-type":"quorum"}' \
-u admin -p Admin@123
```

Bind queue vào exchange:

```bash
sudo rabbitmqadmin declare binding \
source=school_events \
destination=school.email \
destination_type=queue \
-u admin -p Admin@123

sudo rabbitmqadmin declare binding \
source=school_events \
destination=school.ad \
destination_type=queue \
-u admin -p Admin@123

sudo rabbitmqadmin declare binding \
source=school_events \
destination=school.audit \
destination_type=queue \
-u admin -p Admin@123
```

---

# 9. Cài HAProxy

Trên `192.168.100.9`:

```bash
sudo apt update
sudo apt install haproxy -y
```

Sửa config:

```bash
sudo nano /etc/haproxy/haproxy.cfg
```

Thêm cuối file:

```text
listen rabbitmq_amqp
    bind *:5672
    mode tcp
    balance roundrobin
    option tcp-check
    server rabbitmq-01 192.168.100.10:5672 check
    server rabbitmq-02 192.168.100.11:5672 check
    server rabbitmq-03 192.168.100.12:5672 check

listen rabbitmq_ui
    bind *:15672
    mode http
    balance roundrobin
    option httpchk GET /
    server rabbitmq-01 192.168.100.10:15672 check
    server rabbitmq-02 192.168.100.11:15672 check
    server rabbitmq-03 192.168.100.12:15672 check
```

Restart:

```bash
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```

Truy cập UI:

```text
http://192.168.100.9:15672
```

---

# 10. Producer dùng HAProxy IP

`producer.py` trên app01:

```python
import pika
import json
import time

credentials = pika.PlainCredentials("admin", "Admin@123")

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="192.168.100.9",
        port=5672,
        credentials=credentials
    )
)

channel = connection.channel()

message = {
    "event": "student.created",
    "student_id": "S1001",
    "name": "Nguyen Van A",
    "grade": "Grade 10"
}

channel.basic_publish(
    exchange="school_events",
    routing_key="",
    body=json.dumps(message),
    properties=pika.BasicProperties(
        delivery_mode=2
    )
)

print("Message sent:", message)

connection.close()
```

Cài thư viện:

```bash
sudo apt install python3-pip -y
pip3 install pika
```

Chạy:

```bash
python3 producer.py
```

---

# 11. Test HA thật

Tắt node 1:

```bash
sudo systemctl stop rabbitmq-server
```

Gửi message lại:

```bash
python3 producer.py
```

Nếu message vẫn gửi được → HAProxy + RabbitMQ Cluster hoạt động.

Kiểm tra cluster:

```bash
sudo rabbitmqctl cluster_status
```

---

# 12. Mô hình doanh nghiệp thực tế

```text
PowerSchool / Portal
        |
        v
HAProxy RabbitMQ VIP
192.168.100.9
        |
        v
RabbitMQ Cluster 3 Nodes
        |
        +--> school.email
        +--> school.ad
        +--> school.audit
        +--> school.google
        +--> school.library
```

Trong thực tế:

| Queue            | Service xử lý             |
| ---------------- | ------------------------- |
| `school.email`   | Gửi welcome email         |
| `school.ad`      | Tạo AD account            |
| `school.google`  | Tạo Google Workspace user |
| `school.library` | Tạo account thư viện      |
| `school.audit`   | Ghi log về ELK/Zabbix     |

Điểm quan trọng: **RabbitMQ cluster không tự replicate message cho classic queue bình thường**; muốn HA cho message thì dùng **Quorum Queue**. Cluster chỉ chia sẻ metadata, còn queue data cần queue type hỗ trợ replication.

[1]: https://www.rabbitmq.com/docs/quorum-queues?utm_source=chatgpt.com "Quorum Queues"

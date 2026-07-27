# LAB Kafka cho người mới bắt đầu — Ubuntu 24.04

> Mục tiêu: dựng Kafka cluster 3 node chạy **KRaft** (không dùng ZooKeeper), tạo dữ liệu, sao lưu lạnh (cold backup), phục hồi và kiểm chứng dữ liệu.

## 1. Kết quả cần đạt

Sau LAB, bạn sẽ có:

- Cluster Kafka 3 broker/controller, chịu được hỏng 1 node ở mức replication factor 3.
- Topic `orders` có 3 partition, replication factor 3 và `min.insync.replicas=2`.
- Bản sao lưu nhất quán gồm dữ liệu Kafka, metadata KRaft và cấu hình.
- Một lần restore thử nghiệm: dữ liệu tạo **sau** thời điểm backup sẽ không còn.

## 2. Kiến trúc và điều kiện

| Node | Hostname | IP | Vai trò |
|---|---|---:|---|
| 1 | `kafka-01` | `192.168.99.132` | broker + controller |
| 2 | `kafka-02` | `192.168.99.133` | broker + controller |
| 3 | `kafka-03` | `192.168.99.134` | broker + controller |

- Hệ điều hành: Ubuntu Server 24.04 trên ba máy/VM.
- Tài nguyên tối thiểu mỗi node: 2 vCPU, 4 GB RAM, 30 GB disk trống.
- Các node phân giải được hostname của nhau; ví dụ dưới đây dùng `/etc/hosts`.
- Thực hiện phần cài đặt với tài khoản có `sudo`.
- LAB dùng `PLAINTEXT` để đơn giản. Không áp dụng nguyên trạng cho môi trường production có dữ liệu nhạy cảm.

Các cổng cần mở **giữa ba node**:

- TCP `9092`: client và trao đổi giữa broker.
- TCP `9093`: KRaft controller quorum.

Ví dụ, trên *mỗi node* (thay dải mạng nếu thực tế khác):

```bash
sudo ufw allow from 192.168.99.0/24 to any port 9092 proto tcp
sudo ufw allow from 192.168.99.0/24 to any port 9093 proto tcp
sudo ufw status
```

## 3. Chuẩn bị ba máy

### 3.1. Đặt hostname

Chạy tương ứng trên từng máy:

```bash
# node 1
sudo hostnamectl set-hostname kafka-01

# node 2
sudo hostnamectl set-hostname kafka-02

# node 3
sudo hostnamectl set-hostname kafka-03
```

Trên **cả ba node**, mở `/etc/hosts` bằng `sudoedit /etc/hosts`. Nếu có dòng dạng `127.0.1.1 kafka-01` (hoặc hostname của chính máy), hãy xóa hostname khỏi dòng đó hoặc comment dòng đó. Nếu không, Ubuntu sẽ ưu tiên loopback và Kafka controller không kết nối được giữa các node.

Sau đó bảo đảm ba dòng sau xuất hiện **và không bị trùng hostname với một IP khác**:

```text
192.168.99.132 kafka-01
192.168.99.133 kafka-02
192.168.99.134 kafka-03
```

Kiểm tra từ mỗi node:

```bash
getent hosts kafka-01 kafka-02 kafka-03
ping -c 2 kafka-02
```

Kết quả `getent` trên mọi node phải lần lượt là `.132`, `.133`, `.134`; không được có `127.0.1.1`.

### 3.2. Cài Java và Kafka

Chạy trên **cả ba node**. Ví dụ này cố định Kafka `4.3.1` (bản binary hiện có trên Apache download tại thời điểm viết); nếu đổi phiên bản, hãy dùng cùng một phiên bản trên mọi node.

```bash
set -euo pipefail
sudo apt update
sudo apt install -y openjdk-17-jre-headless wget tar
java -version

export KAFKA_VERSION='4.3.1'
test -n "${KAFKA_VERSION}"
cd /tmp
wget "https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz"
sudo tar -xzf "kafka_2.13-${KAFKA_VERSION}.tgz" -C /opt
sudo ln -sfn "/opt/kafka_2.13-${KAFKA_VERSION}" /opt/kafka

id -u kafka >/dev/null 2>&1 || sudo useradd --system --home /var/lib/kafka --shell /usr/sbin/nologin kafka
sudo install -d -o kafka -g kafka -m 0750 /var/lib/kafka/data /var/lib/kafka/metadata
sudo install -d -o root -g kafka -m 0750 /etc/kafka
```

> Nếu URL tải không còn tồn tại, lấy đúng file nhị phân từ [Apache Kafka Downloads](https://kafka.apache.org/downloads), rồi thay `KAFKA_VERSION` và tên file cho nhất quán trên cả ba node. `set -u` trong ví dụ sẽ dừng ngay nếu vô tình dùng một biến chưa được khai báo.

## 4. Cấu hình KRaft cluster

### 4.1. Tạo file cấu hình

Trên **kafka-01**, tạo `/etc/kafka/server.properties` với nội dung sau:

```properties
process.roles=broker,controller
node.id=1

# Dùng IP cố định để controller quorum không phụ thuộc DNS / /etc/hosts.
controller.quorum.voters=1@192.168.99.132:9093,2@192.168.99.133:9093,3@192.168.99.134:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://192.168.99.132:9092,CONTROLLER://192.168.99.132:9093
advertised.listeners=PLAINTEXT://192.168.99.132:9092
inter.broker.listener.name=PLAINTEXT
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT

log.dirs=/var/lib/kafka/data
metadata.log.dir=/var/lib/kafka/metadata

num.partitions=3
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=false
```

Trên **kafka-02** và **kafka-03**, dùng nội dung y hệt, chỉ thay ba dòng bên dưới theo bảng:

| Node | `node.id` | `listeners` | `advertised.listeners` |
|---|---:|---|---|
| kafka-02 | `2` | `PLAINTEXT://192.168.99.133:9092,CONTROLLER://192.168.99.133:9093` | `PLAINTEXT://192.168.99.133:9092` |
| kafka-03 | `3` | `PLAINTEXT://192.168.99.134:9092,CONTROLLER://192.168.99.134:9093` | `PLAINTEXT://192.168.99.134:9092` |

Phân quyền file trên từng node:

```bash
sudo chown root:kafka /etc/kafka/server.properties
sudo chmod 0640 /etc/kafka/server.properties
```

**Kiểm tra bắt buộc trước khi format:** trên từng node, chạy lệnh dưới đây. `node.id`, `listeners` và `advertised.listeners` phải đúng IP của node đó; các dòng còn lại phải thống nhất trên cả ba node.

```bash
sudo grep -E '^(process.roles|node.id|controller.quorum.voters|controller.listener.names|listeners|advertised.listeners|inter.broker.listener.name|listener.security.protocol.map)=' /etc/kafka/server.properties
```

### 4.2. Tạo một Cluster ID duy nhất và format storage

Trên **kafka-01**, sinh Cluster ID và ghi lại giá trị này ở nơi an toàn:

```bash
sudo /opt/kafka/bin/kafka-storage.sh random-uuid
```

Đặt kết quả vào biến `CLUSTER_ID` **giống nhau trên cả ba node**. Ví dụ:

```bash
CLUSTER_ID='THAY_BANG_UUID_VUA_TAO'
sudo /opt/kafka/bin/kafka-storage.sh format --config /etc/kafka/server.properties --cluster-id "$CLUSTER_ID"
```

Chỉ chạy `format` **một lần trước khi cluster có dữ liệu**. Không chạy lại lệnh này trên node đang có dữ liệu: nó có thể làm metadata không còn khớp với cluster.

### 4.3. Chạy Kafka bằng systemd

Trên **cả ba node**, tạo thư mục log mà Kafka launcher dùng mặc định. Kafka sẽ ghi GC log vào `/opt/kafka/logs`; thư mục này phải thuộc user chạy service (`kafka`).

```bash
KAFKA_HOME="$(readlink -f /opt/kafka)"
sudo install -d -o kafka -g kafka -m 0750 "$KAFKA_HOME/logs"
sudo chown -R kafka:kafka "$KAFKA_HOME/logs"
```

Sau đó tạo `/etc/systemd/system/kafka.service`:

```ini
[Unit]
Description=Apache Kafka (KRaft)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/opt/kafka/bin/kafka-server-start.sh /etc/kafka/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
LimitNOFILE=100000
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
```

Khởi động service trên **cả ba node**. Lần khởi động đầu có thể mất vài giây để ba controller bầu leader.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kafka
sudo systemctl status kafka --no-pager -l
```

Khi có lỗi, xem log của node đó:

```bash
sudo journalctl -u kafka -n 100 --no-pager
```

### 4.4. Health check trước khi dùng Kafka CLI

Không chạy `kafka-topics.sh` hoặc `kafka-metadata-quorum.sh` nếu broker chưa mở port. Trên **mỗi node**, kiểm tra:

```bash
sudo ss -lntp | grep -E ':9092|:9093'
```

Mỗi node phải có cả `IP-node:9092` (broker) và `IP-node:9093` (controller). Nếu chỉ có `9093`, controller chưa có leader hoặc broker chưa hoàn tất khởi động. Kiểm tra kết nối controller từ `kafka-01`:

```bash
for ip in 192.168.99.132 192.168.99.133 192.168.99.134; do
  timeout 2 bash -c "echo >/dev/tcp/$ip/9093" \
    && echo "$ip:9093 OK" \
    || echo "$ip:9093 FAILED"
done
```

Chỉ khi cả ba là `OK`, tiếp tục phần 5. Nếu một node có `Permission denied` liên quan `/opt/kafka/.../logs`, dừng service rồi chạy lại phần tạo thư mục log ở 4.3 trên **chính node đó**.

## 5. Kiểm tra cluster và tạo dữ liệu

Chạy các lệnh trong phần này từ `kafka-01` (hoặc máy có Kafka CLI và truy cập được port 9092).

```bash
BOOTSTRAP='192.168.99.132:9092,192.168.99.133:9092,192.168.99.134:9092'

/opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server "$BOOTSTRAP"
```

Tạo topic bền vững `orders`:

```bash
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --create --topic orders --partitions 3 --replication-factor 3 \
  --config min.insync.replicas=2

/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
  --describe --topic orders
```

Kết quả mô tả topic phải cho thấy mỗi partition có ba replica và `Isr` có đủ ba broker trước khi tiếp tục. Gửi sáu bản ghi có khóa:

```bash
printf 'order-001:created\norder-002:created\norder-003:created\norder-004:created\norder-005:created\norder-006:created\n' \
| /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "$BOOTSTRAP" --topic orders \
    --property parse.key=true --property key.separator=:
```

Đọc lại toàn bộ dữ liệu bằng group mới:

```bash
/opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server "$BOOTSTRAP" --topic orders \
  --group lab-before-backup --from-beginning --timeout-ms 10000 \
  --property print.key=true --property key.separator=':'
```

## 6. Backup: snapshot lạnh nhất quán

### 6.1. Vì sao phải dừng toàn bộ cluster?

Kafka ghi dữ liệu và metadata liên tục trên nhiều node. Việc chép riêng thư mục `log.dirs` khi broker vẫn chạy có thể tạo bản sao không nhất quán. Trong LAB này, ta dừng **cả ba node**, sao chép đồng thời dữ liệu và KRaft metadata. Cách này tạo bản backup có thể khôi phục đúng cluster tại thời điểm dừng, nhưng có downtime.

Để backup không downtime hoặc phục hồi sang cluster/region khác, cách phù hợp hơn là replication sang một cluster DR độc lập (MirrorMaker 2/Cluster Linking tùy phiên bản và giấy phép) hoặc snapshot storage có cơ chế consistency. Đây là nội dung nâng cao, không thay thế bằng việc copy nóng thư mục Kafka.

### 6.2. Ghi nhận thời điểm backup và dừng cluster

Trên máy quản trị (có SSH tới ba node), tạo biến timestamp. Sau đó dừng broker theo thứ tự bất kỳ; khi cả ba đã dừng thì producer/consumer sẽ không thể ghi thêm.

```bash
BACKUP_TS=$(date -u +%Y%m%dT%H%M%SZ)
echo "$BACKUP_TS"

for host in kafka-01 kafka-02 kafka-03; do
  ssh "$host" 'sudo systemctl stop kafka && sudo systemctl is-active kafka'
done
```

Mỗi lệnh cuối phải trả về `inactive` (hoặc `failed` chỉ khi service đã dừng; kiểm tra thêm `systemctl status kafka`).

### 6.3. Tạo archive trên từng node

Ví dụ lưu backup cục bộ tại `/var/backups/kafka`. Thay đường dẫn này bằng ổ đĩa/backup server khác trong thực tế. Thực hiện trên **từng node** với đúng tên node:

```bash
sudo install -d -m 0700 /var/backups/kafka
sudo tar --xattrs --acls -C / -czf "/var/backups/kafka/kafka-$(hostname)-${BACKUP_TS}.tgz" \
  etc/kafka var/lib/kafka
sudo sha256sum "/var/backups/kafka/kafka-$(hostname)-${BACKUP_TS}.tgz" \
  | sudo tee "/var/backups/kafka/kafka-$(hostname)-${BACKUP_TS}.tgz.sha256"
```

Sao chép cả ba cặp `.tgz` và `.sha256` sang một nơi khác với cluster (object storage, backup server, hoặc storage đã mã hóa). **Không** coi backup nằm cùng disk với Kafka là một bản backup an toàn.

Sau khi archive và checksum thành công, bật cluster lại:

```bash
for host in kafka-01 kafka-02 kafka-03; do
  ssh "$host" 'sudo systemctl start kafka'
done
```

Chờ cluster ổn định, rồi xác nhận:

```bash
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic orders
```

## 7. Bài thực hành restore có kiểm chứng

Mục tiêu: chứng minh rằng restore đưa cluster quay về đúng thời điểm backup.

### 7.1. Tạo dữ liệu sau backup

Khi cluster đã khỏe, ghi thêm một bản ghi:

```bash
printf 'order-007:after-backup\n' \
| /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "$BOOTSTRAP" --topic orders \
    --property parse.key=true --property key.separator=:
```

Xác nhận `order-007` đọc được trước restore. Khi restore thành công, bản ghi này phải biến mất.

### 7.2. Dừng và cô lập dữ liệu hiện tại

Trên **cả ba node**, dừng Kafka. Sau đó đổi tên thư mục hiện có thay vì xóa ngay, để có đường lui nếu thao tác sai:

```bash
sudo systemctl stop kafka
sudo mv /var/lib/kafka "/var/lib/kafka.pre-restore-${BACKUP_TS}"
sudo install -d -o kafka -g kafka -m 0750 /var/lib/kafka
```

> Lệnh `mv` yêu cầu `var/lib/kafka` và thư mục backup ở cùng filesystem, điều thường đúng trong LAB. Nếu không đúng, hãy dùng một tên thư mục trên cùng volume hoặc chụp snapshot trước khi tiếp tục.

### 7.3. Kiểm tra archive rồi giải nén

Chọn đúng archive theo node đang thao tác:

| Node đang restore | Tên archive |
|---|---|
| `kafka-01` | `kafka-kafka-01-${BACKUP_TS}.tgz` |
| `kafka-02` | `kafka-kafka-02-${BACKUP_TS}.tgz` |
| `kafka-03` | `kafka-kafka-03-${BACKUP_TS}.tgz` |

Ví dụ bên dưới là cho `kafka-01`; trên hai node còn lại thay `kafka-01` bằng hostname tương ứng:

```bash
cd /var/backups/kafka
sudo sha256sum -c "kafka-kafka-01-${BACKUP_TS}.tgz.sha256"
sudo tar --xattrs --acls -C / -xzf "kafka-kafka-01-${BACKUP_TS}.tgz"
sudo chown -R kafka:kafka /var/lib/kafka
sudo find /var/lib/kafka -type d -exec chmod 0750 {} \;
```

File `/etc/kafka/server.properties` trong archive cũng được trả lại. Nếu bạn đã thay đổi cấu hình có chủ đích sau khi backup, so sánh nó với bản hiện hành trước khi khởi động.

### 7.4. Khởi động và xác minh restore

Khởi động ba node, rồi chờ controller quorum và replica ổn định:

```bash
for host in kafka-01 kafka-02 kafka-03; do
  ssh "$host" 'sudo systemctl start kafka'
done

/opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server "$BOOTSTRAP" describe --status
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --describe --topic orders
```

Đọc bằng group mới:

```bash
/opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server "$BOOTSTRAP" --topic orders \
  --group lab-after-restore --from-beginning --timeout-ms 10000 \
  --property print.key=true --property key.separator=':'
```

Tiêu chí pass:

- Có `order-001` đến `order-006`.
- **Không có** `order-007:after-backup`.
- Mỗi partition của `orders` có `ReplicationFactor: 3` và `Isr` đủ 3 broker.

Khi đã xác minh và không còn cần rollback, mới cân nhắc xóa các thư mục `kafka.pre-restore-*`; trong LAB nên giữ lại đến hết buổi học.

## 8. Bài kiểm tra sự cố nhỏ

1. Dừng `kafka-03`: `sudo systemctl stop kafka`.
2. Từ `kafka-01`, kiểm tra `orders` và quan sát một replica vắng khỏi ISR.
3. Gửi thêm dữ liệu với producer có `acks=all`:

```bash
printf 'order-008:while-kafka-03-down\n' | /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server "$BOOTSTRAP" --topic orders \
  --property parse.key=true --property key.separator=: \
  --producer-property acks=all
```

4. Khởi động lại `kafka-03`, chờ ISR đầy đủ rồi đọc dữ liệu để xác nhận broker bắt kịp.

Không dừng đồng thời hai broker khi `min.insync.replicas=2` và producer dùng `acks=all`: ghi mới có thể bị từ chối để bảo vệ độ bền dữ liệu.

## 9. Checklist xử lý lỗi thường gặp

| Triệu chứng | Kiểm tra / hướng xử lý |
|---|---|
| `mkdir: cannot create directory '/opt/kafka/.../logs': Permission denied` hoặc JVM không tạo được `kafkaServer-gc.log` | Dừng service. Lấy đường dẫn thật bằng `KAFKA_HOME="$(readlink -f /opt/kafka)"`, rồi chạy `sudo install -d -o kafka -g kafka -m 0750 "$KAFKA_HOME/logs"` và `sudo chown -R kafka:kafka "$KAFKA_HOME/logs"`. Khởi động lại service. |
| `getent hosts kafka-01` trả về `127.0.1.1` | Sửa `/etc/hosts`: bỏ/comment mapping loopback có hostname, giữ duy nhất mapping `192.168.99.132 kafka-01` (và tương tự hai node còn lại). |
| `kafka-metadata-quorum.sh` báo `Connection ... could not be established` | Không chạy lại CLI liên tục. Trước hết chạy `systemctl status kafka`, `journalctl -u kafka -n 100`, và `ss -lntp | grep -E ':9092|:9093'` trên cả ba node. |
| Có `9093` nhưng không có `9092` | Controller quorum chưa sẵn sàng hoặc broker chưa hoàn tất khởi động. Xác minh mọi node dùng cùng `controller.quorum.voters`, kiểm tra TCP 9093 giữa các node bằng health check ở 4.4, rồi xem log service. |
| Client kết nối được bootstrap nhưng không gửi/đọc được | Kiểm tra `advertised.listeners` phải là IP/hostname client truy cập được; không dùng `0.0.0.0`. |
| Broker không khởi động sau format | So sánh `cluster.id` trong các `meta.properties`; mọi node phải dùng cùng Cluster ID và quorum voters giống nhau. |
| Controller quorum không có leader | Kiểm tra TCP 9093, `controller.quorum.voters`, thời gian hệ thống và ít nhất 2/3 controller đang chạy. Khi dùng `/etc/hosts`, xác minh hostname không phân giải về loopback. |
| Topic dưới-replicated | `kafka-topics.sh --describe`, log service và dung lượng disk; khởi động node thiếu rồi chờ ISR bắt kịp. |
| Restore không đúng dữ liệu | Xác minh checksum, archive đúng timestamp cho đúng node, và đã dừng **toàn bộ** broker trước khi snapshot. |

## 10. Sau LAB: các điểm cần nâng cấp cho production

- Tách controller và broker thay vì combined mode; combined mode phù hợp môi trường phát triển/lab hơn.
- Bật TLS/SASL, ACL, mã hóa backup và quản lý secrets.
- Dùng monitoring (JMX/Prometheus), cảnh báo under-replicated partitions, disk, controller health và consumer lag.
- Đặt retention, phân vùng, replication, `min.insync.replicas` theo RPO/RTO và tải thực tế.
- Thiết kế DR bằng cluster độc lập, replication và diễn tập failover; cold backup chỉ phù hợp khi chấp nhận downtime/RTO tương ứng.

## Tài liệu tham khảo

- [Apache Kafka — KRaft operations](https://kafka.apache.org/40/operations/kraft/): vai trò controller/broker, controller quorum và lưu ý combined mode.
- [Apache Kafka — Broker configuration](https://kafka.apache.org/40/configuration/broker-configs/): `node.id`, `process.roles`, `log.dirs` và các cấu hình broker.
- [Apache Kafka Downloads](https://kafka.apache.org/downloads): tải bản binary và kiểm tra tính toàn vẹn trước khi triển khai.

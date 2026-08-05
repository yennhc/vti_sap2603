# LAB: Xây Dựng Prometheus + Grafana và Kết Nối với Zabbix

**Môn học:** Hệ Thống Linux – Giám Sát Hạ Tầng
**Thời lượng dự kiến:** 120–150 phút
**Cấp độ:** Trung cấp – Nâng cao
**Điều kiện tiên quyết:** Đã hoàn thành Lab "Triển Khai Zabbix Server & Zabbix Agent trên Ubuntu 24.04"

---

## 1. Mục Tiêu Bài Lab

Sau khi hoàn thành lab này, học sinh có thể:

- Cài đặt Prometheus và node_exporter để thu thập metric hệ thống
- Cài đặt Grafana và cấu hình làm systemd service
- Kết nối Grafana với Prometheus qua data source
- Cài plugin `grafana-zabbix` để kết nối Grafana với Zabbix API
- Tạo user API read-only riêng cho Grafana trong Zabbix (thực hành nguyên tắc least privilege)
- Xây dựng một dashboard tổng hợp hiển thị dữ liệu từ cả hai nguồn

## 2. Mô Hình Lab

```
┌───────────────────┐     scrape       ┌───────────────────┐
│  node_exporter       │◄─────────────────┤   Prometheus        │
│  (port 9100)          │                  │   (port 9090)        │
└───────────────────┘                  └─────────┬─────────┘
                                                  │ datasource
┌───────────────────┐   API JSON-RPC             ▼
│  Zabbix Server        │◄──────────────────►┌───────────────────┐
│  (port 80, đã cài từ  │    datasource        │     Grafana          │
│   lab trước)           │                  │   (port 3000)        │
└───────────────────┘                  └───────────────────┘
```

| Máy | Vai trò | IP mẫu | Ghi chú |
|---|---|---|---|
| zabbix-server | Zabbix Server (đã có) | 10.0.0.10 | Từ lab trước |
| monitoring-01 | Prometheus + node_exporter + Grafana | 10.0.0.30 | Có thể dùng chung máy với Zabbix nếu tài nguyên đủ |

> Có thể cài Prometheus/Grafana trên cùng máy với Zabbix Server để đơn giản hóa lab, miễn là máy có tối thiểu 2 vCPU / 4GB RAM.

## 3. Yêu Cầu Tiên Quyết

- Máy Ubuntu 24.04 đã cập nhật: `sudo apt update && sudo apt upgrade -y`
- Đã có Zabbix Server đang chạy (hoàn thành ở lab trước)
- Quyền `sudo`
- `wget`, `tar` đã có sẵn (mặc định trên Ubuntu)

---

## 4. Phần A — Cài Đặt Prometheus

### Bước A1: Tạo user hệ thống và thư mục

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus /var/lib/prometheus
```

### Bước A2: Tải và giải nén Prometheus

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
tar xvf prometheus-2.53.0.linux-amd64.tar.gz
cd prometheus-2.53.0.linux-amd64

sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus/
sudo cp prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus \
  /usr/local/bin/prometheus /usr/local/bin/promtool
```

### Bước A3: Cấu hình scrape target

```bash
sudo vi /etc/prometheus/prometheus.yml
```

Nội dung:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

### Bước A4: Tạo systemd service

```bash
sudo vi /etc/systemd/system/prometheus.service
```

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
```

Kiểm tra: truy cập `http://<ip>:9090` → menu **Status → Targets** phải thấy job `prometheus` ở trạng thái `UP`.

### Bước A5: Cài node_exporter

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter
```

Tạo service `/etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
```

Xác nhận job `node` chuyển sang `UP` trong **Status → Targets** của Prometheus.

---

## 5. Phần B — Cài Đặt Grafana

### Bước B1: Thêm repository Grafana chính thức

```bash
sudo apt install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
  sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt update
```

### Bước B2: Cài và khởi động Grafana

```bash
sudo apt install grafana -y
sudo systemctl enable --now grafana-server
```

### Bước B3: Đăng nhập lần đầu

Truy cập `http://<ip>:3000`, đăng nhập `admin` / `admin`, đổi mật khẩu khi được yêu cầu.

### Bước B4: Mở firewall (nếu dùng UFW)

```bash
sudo ufw allow 9090/tcp   # Prometheus
sudo ufw allow 9100/tcp   # node_exporter
sudo ufw allow 3000/tcp   # Grafana
```

---

## 6. Phần C — Kết Nối Grafana với Prometheus

1. Vào **Connections → Data sources → Add data source → Prometheus**
2. URL: `http://localhost:9090` (hoặc IP của máy Prometheus nếu khác máy Grafana)
3. Access: `Server (default)`
4. Bấm **Save & Test** → phải thấy thông báo xanh xác nhận kết nối thành công

---

## 7. Phần D — Kết Nối Grafana với Zabbix

### Bước D1: Cài plugin grafana-zabbix

```bash
#sudo grafana-cli plugins install alexanderzobnin-zabbix-app
sudo grafana-cli --homepath="/usr/share/grafana" plugins install alexanderzobnin-zabbix-app
sudo systemctl restart grafana-server
```

Vào **Administration → Plugins**, tìm **Zabbix**, bấm **Enable**.

### Bước D2: Tạo user API read-only trong Zabbix (nguyên tắc least privilege)

Trong Zabbix UI: **Users → Users → Create user**

| Trường | Giá trị |
|---|---|
| Username | `grafana-reader` |
| Password | đặt mật khẩu riêng, không dùng chung với Admin |
| Role | Read-only (hoặc tạo custom role chỉ có quyền xem) |

> Nếu dùng Zabbix 6.4 trở lên, có thể tạo **API token** (Users → API tokens) thay cho user/password để tránh lưu mật khẩu dạng plaintext trong Grafana.

### Bước D3: Thêm data source Zabbix trong Grafana

**Connections → Data sources → Add data source → Zabbix**

| Trường | Giá trị |
|---|---|
| URL | `http://<zabbix-server-ip>/zabbix/api_jsonrpc.php` |
| Auth | User/password (`grafana-reader`) hoặc API token |

Bấm **Save & Test** → kỳ vọng thông báo dạng `Zabbix API version: 7.0.x`.

---

## 8. Phần E — Xây Dựng Dashboard Tổng Hợp

1. Vào **Dashboards → New → New Dashboard → Add visualization**
2. **Panel 1 (nguồn Prometheus):** chọn data source Prometheus, query ví dụ:
   ```
   node_cpu_seconds_total
   ```
3. **Panel 2 (nguồn Zabbix):** chọn data source Zabbix, dùng giao diện chọn trực quan: Host group → Host → Item (ví dụ CPU load hoặc memory utilization)
4. Đặt tên dashboard, ví dụ `Lab - Tong Hop Giam Sat`, và Save

---

## 9. Xác Minh Cài Đặt

```bash
# Kiểm tra các service đang chạy
sudo systemctl status prometheus node_exporter grafana-server

# Kiểm tra Prometheus đang scrape thành công
curl -s http://localhost:9090/api/v1/targets | grep '"health":"up"'

# Kiểm tra node_exporter trả metric
curl -s http://localhost:9100/metrics | head -5
```

Kết quả mong đợi: cả 3 service ở trạng thái `active (running)`, targets Prometheus đều `up`, và dashboard Grafana hiển thị dữ liệu theo thời gian thực từ cả hai panel.

---

## 10. Xử Lý Sự Cố Thường Gặp

| Triệu chứng | Nguyên nhân khả dĩ | Cách khắc phục |
|---|---|---|
| Prometheus target `node` báo `DOWN` | node_exporter chưa chạy hoặc firewall chặn port 9100 | `systemctl status node_exporter`, kiểm tra `ufw status` |
| Grafana không load được trang sau khi cài | Service chưa khởi động hoặc bị chặn port 3000 | `sudo systemctl status grafana-server`, `sudo ufw allow 3000/tcp` |
| Data source Zabbix báo `Zabbix API error: Login name or password is incorrect` | Sai username/password, hoặc user Zabbix bị khóa/disable | Đối chiếu lại thông tin, kiểm tra trạng thái user trong **Users → Users** |
| Data source Zabbix báo lỗi kết nối (connection refused/timeout) | Sai URL API, hoặc Apache trên Zabbix server chưa chạy | Xác nhận URL đúng `/zabbix/api_jsonrpc.php`, `systemctl status apache2` |
| Plugin Zabbix không xuất hiện sau khi cài | Chưa restart lại Grafana, hoặc chưa Enable plugin | `sudo systemctl restart grafana-server`, vào **Administration → Plugins** bật thủ công |
| Panel Prometheus không có dữ liệu dù target `UP` | Sai tên metric trong query, hoặc scrape_interval chưa đủ thời gian | Dùng tab **Explore** trong Grafana để test query trước, đợi ít nhất 1 chu kỳ scrape |

---

## 11. Bài Tập Thực Hành Mở Rộng

1. Tạo một **Alert rule** trong Grafana dựa trên metric `node_cpu_seconds_total`, cảnh báo khi CPU idle time giảm dưới ngưỡng nhất định.
2. So sánh cùng một chỉ số (ví dụ CPU load) hiển thị song song từ Prometheus và từ Zabbix trên cùng một dashboard, giải thích sự khác biệt về cách hai hệ thống thu thập dữ liệu (pull vs. push/passive).
3. (Nâng cao) Tạo một **HTTP agent item** trong Zabbix trỏ tới `http://<exporter-ip>:9100/metrics`, dùng preprocessing rule **Prometheus to JSON** để Zabbix tự thu thập và tạo trigger trên dữ liệu Prometheus mà không cần qua Grafana.
4. Export dashboard vừa tạo ra file JSON và import lại trên một Grafana instance khác, mô tả quy trình backup/restore dashboard.

---



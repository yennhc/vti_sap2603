# LAB: MinIO — Cài Đặt, Quản Trị User/Quyền và Triển Khai Cụm Phân Tán (Erasure Coding)

## Yêu cầu môi trường

- Task 1-4: 1 VM Ubuntu (standalone)
- Task 5: 4 VM Ubuntu (đặt tên `minio1`, `minio2`, `minio3`, `minio4`), mỗi VM có 1 disk/thư mục dữ liệu riêng, cùng chung mạng nội bộ, phân giải được tên nhau (qua `/etc/hosts` hoặc DNS nội bộ)

---

## Task 1: Cài đặt MinIO Server và Client

### Cài MinIO Server

```bash
# Tạo user chạy dịch vụ
sudo groupadd -r minio-user
sudo useradd -M -r -g minio-user minio-user
sudo mkdir -p /mnt/minio-data
sudo chown minio-user:minio-user /mnt/minio-data

# Tải binary
curl -O https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
```

### Cấu hình và tạo systemd service

```bash
sudo tee /etc/default/minio > /dev/null <<'EOF'
MINIO_VOLUMES="/mnt/minio-data"
MINIO_OPTS="--console-address :9001"
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=ChangeMe123!
EOF

sudo tee /etc/systemd/system/minio.service > /dev/null <<'EOF'
[Unit]
Description=MinIO Object Storage
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
Type=notify
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES $MINIO_OPTS
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now minio
sudo systemctl status minio
```

## Check permission
```bash

chown -R minio-user:minio-user /mnt/minio-data
find /mnt/minio_data -type d -exec chmod 755 {} \;
find /mnt/minio_data -type f -exec chmod 644 {} \;

```


Mở firewall (nếu dùng ufw): `sudo ufw allow 9000/tcp && sudo ufw allow 9001/tcp`

Truy cập Console: `http://<IP-VM>:9001` (đăng nhập bằng `minioadmin` / `ChangeMe123!`)

### Cài MinIO Client (mc)

```bash
#curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
#sudo mv mc /usr/local/bin/
sudo curl -L https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
sudo chmod +x /usr/local/bin/mc

# Tạo alias trỏ tới server
mc alias set local http://192.168.100.11:9000 minioadmin ChangeMe123!
mc admin info local
```

---

## Task 2: Tạo User

```bash
# Tạo user mới với access key/secret key riêng
mc admin user add local labuser LabUserPass123!

# Kiểm tra user vừa tạo
mc admin user info local labuser

# Liệt kê toàn bộ user trên hệ thống
mc admin user list local
```

> Mỗi user có access key/secret key riêng, độc lập với `MINIO_ROOT_USER` — dùng để cấp quyền hạn chế thay vì dùng chung tài khoản admin.

---

## Task 3: Upload Object

```bash
# Tạo bucket
mc mb local/lab-bucket

# Upload 1 file
echo "Hello MinIO" > test.txt
mc cp test.txt local/lab-bucket/

# Upload cả thư mục
mc cp --recursive ~/demo-folder/ local/lab-bucket/demo-folder/

# Kiểm tra kết quả
mc ls local/lab-bucket
```

---

## Task 4: Phân Quyền Truy Cập

MinIO phân quyền theo 2 lớp: **Bucket Policy** (public/anonymous access) và **IAM Policy** (gắn cho từng user).

### Cách 1 — Set nhanh quyền truy cập bucket

```bash
# Cho phép đọc công khai (không cần key)
mc anonymous set download local/lab-bucket

# Đưa về private
mc anonymous set none local/lab-bucket

# Kiểm tra trạng thái hiện tại
mc anonymous get local/lab-bucket
```

### Cách 2 — Gán IAM Policy cho user (khuyến nghị dùng trong thực tế)

```bash
# Gán policy có sẵn: readonly / readwrite / writeonly
mc admin policy attach local readonly --user labuser

# Kiểm tra policy đã gán
mc admin policy entities local --user labuser
```

### Cách 3 — Tạo policy tùy chỉnh (giới hạn chỉ 1 bucket)

```bash
cat > lab-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::lab-bucket",
        "arn:aws:s3:::lab-bucket/*"
      ]
    }
  ]
}
EOF

mc admin policy create local lab-bucket-policy lab-policy.json
mc admin policy attach local lab-bucket-policy --user labuser
```

Kiểm chứng: đăng nhập bằng `labuser` (alias riêng) và thử thao tác trên bucket khác để xác nhận bị từ chối quyền.

```bash
mc alias set labuser-session http://127.0.0.1:9000 labuser LabUserPass123!
mc ls labuser-session/lab-bucket        # phải thành công
mc mb labuser-session/bucket-khac       # phải bị từ chối (nếu policy giới hạn đúng bucket)
```

---

## Task 5: Triển Khai Cụm Phân Tán với Erasure Coding

Erasure Coding cho phép cụm MinIO chịu được mất một số node/disk mà vẫn đảm bảo dữ liệu không mất (tương tự RAID nhưng ở mức phân tán). Yêu cầu tối thiểu 4 node để có failover thực sự có ý nghĩa.

### Bước 5.1 — Chuẩn bị 4 VM

Trên **cả 4 VM**: cài MinIO binary giống Task 1 (chỉ cài binary + tạo user/thư mục, **chưa** tạo systemd service).

```bash
sudo groupadd -r minio-user
sudo useradd -M -r -g minio-user minio-user
sudo mkdir -p /mnt/minio-data
sudo chown minio-user:minio-user /mnt/minio-data

curl -O https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
```

Cấu hình `/etc/hosts` trên cả 4 node để các node phân giải được tên nhau:

```
10.0.0.11 minio1
10.0.0.12 minio2
10.0.0.13 minio3
10.0.0.14 minio4
```

### Bước 5.2 — Cấu hình biến môi trường (giống nhau trên cả 4 node)

```bash
sudo tee /etc/default/minio > /dev/null <<'EOF'
MINIO_VOLUMES="http://minio{1...4}:9000/mnt/minio-data"
MINIO_OPTS="--console-address :9001"
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=ChangeMe123!
EOF
```

> Cú pháp `minio{1...4}` là dải node MinIO sẽ tự động dò để tạo cụm — mỗi node chạy cùng câu lệnh này, MinIO tự nhận diện node nào là "chính nó" dựa theo hostname.

### Bước 5.3 — Tạo systemd service (giống nhau trên cả 4 node)

```bash
sudo tee /etc/systemd/system/minio.service > /dev/null <<'EOF'
[Unit]
Description=MinIO Distributed Cluster
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
Type=notify
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES $MINIO_OPTS
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### Bước 5.4 — Khởi động đồng thời trên cả 4 node

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now minio
```

> **Lưu ý:** node đầu tiên khởi động sẽ chờ (log hiện "Waiting for all other servers to be online") cho tới khi đủ 4 node cùng lên — vì vậy cần start gần như đồng thời trên cả 4 VM.

Kiểm tra log:

```bash
sudo journalctl -u minio -f
```

### Bước 5.5 — Kiểm tra tình trạng cụm và Erasure Coding

Từ máy client (có `mc`):

```bash
mc alias set cluster http://minio1:9000 minioadmin ChangeMe123!
mc admin info cluster
```

Kết quả sẽ hiển thị 4 node, dung lượng theo Erasure Set, và thông tin parity (mặc định MinIO tự chọn EC:2 cho cụm 4 node — nghĩa là chịu được mất 2 node mà dữ liệu vẫn đọc được).

### Bước 5.6 — Kiểm chứng khả năng chịu lỗi (failover test)

```bash
# Upload 1 file test
mc mb cluster/test-bucket
mc cp test.txt cluster/test-bucket/

# Tắt 1 node (ví dụ minio2)
ssh minio2 'sudo systemctl stop minio'

# Vẫn đọc/ghi được vì Erasure Coding cho phép mất tối đa 2/4 node
mc cp test.txt cluster/test-bucket/test2.txt
mc ls cluster/test-bucket

# Bật lại node để cụm tự phục hồi (healing)
ssh minio2 'sudo systemctl start minio'
mc admin heal cluster
```

---

## Checklist hoàn thành

- [ ] Task 1: `mc admin info local` chạy thành công trên node standalone
- [ ] Task 2: `mc admin user list local` hiển thị `labuser`
- [ ] Task 3: Object xuất hiện trong `mc ls local/lab-bucket`
- [ ] Task 4: Chứng minh được 1 trường hợp cho phép và 1 trường hợp bị từ chối quyền
- [ ] Task 5: `mc admin info cluster` hiển thị đủ 4 node online; tắt 1 node vẫn upload/download được

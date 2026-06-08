**APT, DPKG, Snap, PPA, Repository, Package Dependency, Service Management**.

# LAB 1 - Quản lý Package bằng APT

### Mục tiêu

* Cập nhật package
* Tìm kiếm package
* Cài đặt và gỡ bỏ package

### Yêu cầu

1. Cập nhật repository

```bash
sudo apt update
```

2. Nâng cấp hệ thống

```bash
sudo apt upgrade -y
```

3. Tìm package nginx

```bash
apt search nginx
```

4. Cài đặt nginx

```bash
sudo apt install nginx -y
```

5. Kiểm tra version

```bash
nginx -v
```

6. Gỡ nginx

```bash
sudo apt remove nginx
```

7. Xóa hoàn toàn

```bash
sudo apt purge nginx
```

---

# LAB 2 - Quản lý Package bằng DPKG

### Mục tiêu

* Cài package .deb
* Kiểm tra package đã cài

### Yêu cầu

Tải package htop

```bash
sudo apt purge htop
apt download htop
```

Cài bằng dpkg

```bash
sudo dpkg -i htop_*.deb
```

Kiểm tra

```bash
dpkg -l | grep htop
```

Liệt kê file

```bash
dpkg -L htop
```

Gỡ package

```bash
sudo dpkg -r htop
```

---

# LAB 3 - Tìm hiểu Dependency

### Mục tiêu

* Hiểu package phụ thuộc

### Yêu cầu

Xem dependency của nginx

```bash
apt-cache depends nginx
```

Xem package phụ thuộc ngược

```bash
apt-cache rdepends nginx
```

Kiểm tra package bị lỗi dependency

```bash
sudo apt --fix-broken install
```

---

# LAB 4 - Quản lý Repository

### Mục tiêu

* Hiểu nguồn cài đặt package

### Yêu cầu

Liệt kê repository

```bash
cat /etc/apt/sources.list
```

Kiểm tra các file repository

```bash
ls /etc/apt/sources.list.d/
```

Cập nhật repository

```bash
sudo apt update
```

Xem package đến từ repository nào

```bash
apt policy nginx
```

---

# LAB 5 - Quản lý PPA

### Mục tiêu

* Thêm repository bên thứ ba

### Yêu cầu

Thêm PPA Git

```bash
sudo add-apt-repository ppa:git-core/ppa
```

Update

```bash
sudo apt update
```

Kiểm tra version

```bash
git --version
```

Xóa PPA

```bash
sudo add-apt-repository --remove ppa:git-core/ppa
```

---

# LAB 6 - Quản lý Snap

### Mục tiêu

* Sử dụng Snap Store

### Yêu cầu

Tìm package

```bash
snap find vlc
```

Cài đặt

```bash
sudo snap install vlc
```

Kiểm tra

```bash
snap list
```

Refresh

```bash
sudo snap refresh
```

Gỡ bỏ

```bash
sudo snap remove vlc
```

---

# LAB 7 - Quản lý Service sau khi cài Package

### Mục tiêu

* Kết hợp Software Management và Systemd

### Yêu cầu

Cài nginx

```bash
sudo apt install nginx -y
```

Kiểm tra service

```bash
systemctl status nginx
```

Khởi động

```bash
sudo systemctl start nginx
```

Enable

```bash
sudo systemctl enable nginx
```

Kiểm tra port

```bash
ss -tulpn | grep 80
```

---

# LAB 8 - Rollback và Version Management

### Mục tiêu

* Quản lý phiên bản package

### Yêu cầu

Kiểm tra version

```bash
apt policy nginx
```

Liệt kê version

```bash
apt-cache madison nginx
```

Cài version cụ thể

```bash
sudo apt install nginx=<version>
```

Khóa version

```bash
sudo apt-mark hold nginx
```

Kiểm tra

```bash
apt-mark showhold
```

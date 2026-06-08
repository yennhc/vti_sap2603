
---

# 🐧 LINUX PACKAGE MANAGEMENT

---

## 📦 1. UPDATE & UPGRADE

```bash
sudo apt update          # Cập nhật danh sách package
sudo apt upgrade         # Nâng cấp package đã cài
sudo apt full-upgrade    # Upgrade + xử lý dependency nâng cao
```

---

## 📥 2. INSTALL PACKAGE

```bash
sudo apt install <package>              # Cài 1 package
sudo apt install vim git curl          # Cài nhiều package
sudo apt install -y nginx              # Auto yes (automation)
```

📌 Kiểm tra đã cài:

```bash
dpkg -l | grep <package>
```

📌 Xem thông tin:

```bash
apt show <package>
```

---

## 📤 3. REMOVE / PURGE

```bash
sudo apt remove <package>   # Xóa nhưng giữ config
sudo apt purge <package>    # Xóa sạch (config + data)
```

📌 Dọn dependency:

```bash
sudo apt autoremove
```

---

## 🔗 4. DEPENDENCY (CỰC QUAN TRỌNG)

```bash
apt depends <package>       # Xem dependency
apt rdepends <package>      # Package nào phụ thuộc vào nó
```

📌 Insight:

* APT tự resolve dependency tree
* Lỗi thường do dependency conflict

---

## 📊 5. VERSION CONTROL

```bash
apt list -a <package>                   # Xem tất cả version
sudo apt install <package>=<version>    # Cài version cụ thể
```

📌 Ví dụ:

```bash
sudo apt install nginx=1.18.*
```

---

## 📁 6. REPOSITORY

```bash
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/
```

📌 Sau khi sửa repo:

```bash
sudo apt update
```

---

## 🔍 7. SEARCH PACKAGE

```bash
apt search <keyword>
apt-cache search <keyword>
```

---

## 🛠️ 8. TROUBLESHOOTING

### ❌ Lỗi phổ biến:

```bash
E: Unable to locate package
```

👉 Fix:

```bash
sudo apt update
```

---

### ❌ Broken packages:

```bash
sudo apt --fix-broken install
```

---

### ❌ Lock error:

```bash
sudo rm /var/lib/dpkg/lock*
sudo dpkg --configure -a
```

---

## ⚙️ 9. BUILD FROM SOURCE

```bash
sudo apt install build-essential

wget <url>
tar -xvf file.tar.gz
cd folder

./configure
make
sudo make install
```

📌 Flow:

* configure → check system
* make → compile
* install → copy binary

---

## 🤖 10. AUTOMATION (SCRIPT)

```bash
#!/bin/bash
apt update
apt install -y nginx git curl
```

📌 Use cases:

* Server provisioning
* DevOps pipeline
* Cloud init

---

## 🚀 QUICK COMMAND SUMMARY

| Task         | Command        |
| ------------ | -------------- |
| Update repo  | apt update     |
| Install      | apt install    |
| Remove       | apt remove     |
| Purge        | apt purge      |
| Cleanup      | apt autoremove |
| Search       | apt search     |
| Info         | apt show       |
| Dependencies | apt depends    |

---

## 🎯 BEST PRACTICES

✔ Luôn `apt update` trước khi cài

✔ Dùng `-y` cho automation

✔ Pin version trong production

✔ Dùng `purge` khi cần clean hoàn toàn

✔ Luôn check dependency khi lỗi

---

## 🧠 SYSADMIN MINDSET

* Package ≠ chỉ là phần mềm → là **dependency graph**
* Lỗi ≠ do command → do **system state**
* Luôn hỏi:
  👉 “Package này đến từ đâu?”
  👉 “Nó phụ thuộc cái gì?”
  👉 “Nếu xoá sẽ ảnh hưởng gì?”

---

---
### 🔥 LAB 1 — Server bị đầy disk (Production Incident)

🎯 Tình huống

- Server production báo lỗi:

- App không ghi log được
- Disk / full 100%

🧩 Mục tiêu
- Xác định nguyên nhân
- Giải phóng disk an toàn

📌 Yêu cầu
- Kiểm tra disk:
```bash
df -h
```
Xác định thư mục chiếm nhiều dung lượng:
```bash
sudo du -sh /* 2>/dev/null | head -10 | sort -rh
du -sh /var/*
```

- Tìm file lớn:
```bash
find /var -type f -size +100M
```


### 🔥 LAB 2 — CPU 100% (Performance issue)
🎯 Tình huống

- Server chậm bất thường

📌 Yêu cầu

- Check CPU:
```bash
top
```
- Identify process:
```bash
ps aux --sort=-%cpu | head
watch 'ps aux --sort=-%cpu' | head -10'

Kill nếu cần:
kill -9 <PID>
```



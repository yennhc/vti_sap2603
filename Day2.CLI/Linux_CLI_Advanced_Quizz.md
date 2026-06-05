
---
### 1. Lệnh nào tìm tất cả file .log trong /var và xóa chúng?

```bash
A. rm /var/*.log
B. find /var -name "*.log" -delete 
C. delete /var/*.log
D. grep *.log /var
```
### 2. Lệnh nào hiển thị dòng chứa “error” nhưng không phân biệt hoa thường?

```bash
A. grep error file
B. grep -i error file 
C. grep -r error file
D. grep -v error file
```
### 3. Kết quả của lệnh:
```bash
echo $PATH

A. Danh sách process
B. Biến môi trường chứa đường dẫn executable 
C. Đường dẫn home
D. Thư mục hiện tại
```

### 4. Lệnh nào redirect cả stdout và stderr vào file?
```bash
A. command > file
B. command 2> file
C. command > file 2>&1 
D. command >> file
```
### 5. Lệnh nào đếm số dòng trong file?
```bash
A. count file
B. wc -l file 
C. lines file
D. cat file | count
```

### 6. Ý nghĩa của pipe (|) là gì?
```bash
A. Lưu output vào file
B. Truyền output của command này sang command khác 
C. Chạy song song
D. Chạy background
```

### 7. Lệnh:
```bash
ps aux | grep nginx

Dùng để?
A. Restart nginx
B. Kiểm tra process nginx đang chạy 
C. Xóa nginx
D. Install nginx
```

### 8. Lệnh nào tìm file lớn hơn 100MB?
```bash
A. find / -size +100M 
B. find / -size 100M
C. du -100M
D. ls -100M
```

### 9. Lệnh:
```bash
chmod 644 file.txt

Có nghĩa?
A. Owner: rw-, Group: r--, Others: r-- 
B. Owner: rwx, Group: r-x, Others: r-x
C. All: rwx
D. All: read only
```

### 10. Lệnh nào xem dung lượng thư mục?
```bash
A. df -h
B. du -sh 
C. ls -h
D. size
```

### 11. Lệnh nào kill process theo PID?
```bash
A. stop
B. kill <PID> 
C. terminate
D. end
```

### 12. Lệnh nào xem log realtime?
```bash
A. cat file
B. tail -f file 
C. watch file
D. less file
```

### 13. Lệnh:
```bash
df -h

Dùng để?
A. Xem RAM
B. Xem disk usage 
C. Xem CPU
D. Xem process
```

### 14. Lệnh nào kiểm tra port đang listen?
```bash
A. netstat -tuln 
B. ps -port
C. checkport
D. portscan
```

### 15. Lệnh nào kiểm tra quyền file chi tiết?
```bash
A. ls
B. ls -l 
C. stat
D. chmod
```

### 16. Lệnh:
```bash
find / -type f -name "*.conf" 2>/dev/null

Ý nghĩa?
A. Tìm file .conf và bỏ qua lỗi permission 
B. Xóa file .conf
C. Copy file .conf
D. Restart config
```

### 17. 2>/dev/null dùng để?
```bash
A. Redirect stdout
B. Bỏ qua lỗi (stderr) 
C. Xóa file
D. Log file
```

### 18. Lệnh:
```bash
history | grep ssh

Dùng để?
A. Xem SSH config
B. Tìm command SSH đã chạy trước đó 
C. Restart SSH
D. Login SSH
```

### 19. Lệnh:
```bash
chmod +x script.sh

Dùng để?
A. Chạy script
B. Cấp quyền execute cho file 
C. Copy file
D. Xóa file
```

### 20. Lệnh nào chạy command ở background?
```bash
A. command & 
B. bg command
C. run command
D. async command
```
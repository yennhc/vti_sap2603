# LAB: Self-Signed SSL cho Nginx và IIS

Được. Tôi sẽ hướng dẫn theo mô hình lab của bạn với domain **`vti.lab`**, gồm:

- Ubuntu + Nginx: `web01.vti.lab`
- Windows Server + IIS: `web02.vti.lab`
- Self-signed certificate
- SAN đúng chuẩn
- HTTPS 443
- Cách trust certificate trên client
- Kiểm tra bằng OpenSSL/browser

> **Lưu ý:** Self-signed certificate phù hợp cho **lab, development, internal testing**. Không nên dùng trực tiếp cho website public vì certificate không được CA tin cậy ký. [Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-self-signed-certificate?utm_source=chatgpt.com)
> 

---

# LAB: Self-Signed SSL cho Nginx và IIS

## 1. Mô hình

```
                    vti.lab
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
      web01.vti.lab        web02.vti.lab
         Ubuntu              Windows
         Nginx                 IIS
          │                     │
          │ HTTPS               │ HTTPS
          ▼                     ▼
       TCP/443               TCP/443
```

Ví dụ DNS:

```
web01.vti.lab    → IP Ubuntu
web02.vti.lab    → IP Windows
```

Nếu bạn đã có DC/DNS của `vti.lab`, chỉ cần tạo 2 DNS A record.

---

# PHẦN A — Ubuntu + Nginx

## 2. Cài OpenSSL và Nginx

```
sudo apt update
sudo apt install -y openssl nginx
```

Kiểm tra:

```
openssl version
nginx -v
```

---

# 3. Tạo thư mục SSL

```
sudo mkdir -p /etc/nginx/ssl
sudo chmod 700 /etc/nginx/ssl
```

---

# 4. Tạo Private Key

Tạo RSA 2048:

```
sudo openssl genrsa \
  -out /etc/nginx/ssl/web01.vti.lab.key \
  2048
```

Kiểm tra:

```
sudo openssl rsa \
  -in /etc/nginx/ssl/web01.vti.lab.key \
  -check
```

Kết quả:

```
RSA key ok
```

Private key phải được giữ bí mật.

```
/etc/nginx/ssl/web01.vti.lab.key
```

Không copy file này sang client.

---

# 5. Tạo Self-Signed Certificate có SAN

Đây là phần rất quan trọng.

Không nên chỉ tạo:

```
CN=web01.vti.lab
```

mà phải có:

```
SAN=web01.vti.lab
```

Tạo certificate:

```
sudo openssl req \
  -x509 \
  -new \
  -nodes \
  -key /etc/nginx/ssl/web01.vti.lab.key \
  -sha256 \
  -days 365 \
  -out /etc/nginx/ssl/web01.vti.lab.crt \
  -subj "/C=VN/ST=HCM/L=HCM/O=VTI Lab/OU=IT/CN=web01.vti.lab" \
  -addext "subjectAltName=DNS:web01.vti.lab,DNS:www.web01.vti.lab"
```

OpenSSL hỗ trợ tạo self-signed certificate trực tiếp bằng `openssl req -x509`, đồng thời có thể khai báo SAN bằng extension. [OpenSSL Documentation](https://docs.openssl.org/3.3/man1/openssl-req/?utm_source=chatgpt.com)

---

# 6. Kiểm tra Certificate

```
openssl x509 \
  -in /etc/nginx/ssl/web01.vti.lab.crt \
  -noout \
  -subject \
  -issuer \
  -dates
```

Bạn sẽ thấy:

```
subject=C=VN, ST=HCM, L=HCM, O=VTI Lab, OU=IT, CN=web01.vti.lab

issuer=C=VN, ST=HCM, L=HCM, O=VTI Lab, OU=IT, CN=web01.vti.lab
```

Điểm quan trọng:

```
subject = issuer
```

=> Đây là **self-signed**.

---

# 7. Kiểm tra SAN

```
openssl x509 \
  -in /etc/nginx/ssl/web01.vti.lab.crt \
  -noout \
  -text | grep -A2 "Subject Alternative Name"
```

Kết quả:

```
X509v3 Subject Alternative Name:
    DNS:web01.vti.lab, DNS:www.web01.vti.lab
```

---

# 8. Cấu hình quyền

```
sudo chown root:root /etc/nginx/ssl/*
sudo chmod 600 /etc/nginx/ssl/web01.vti.lab.key
sudo chmod 644 /etc/nginx/ssl/web01.vti.lab.crt
```

---

# 9. Tạo website

```
sudo mkdir -p /var/www/web01.vti.lab
```

```
sudo nano /var/www/web01.vti.lab/index.html
```

Nội dung:

```
<!DOCTYPE html>
<html>
<head>
    <title>VTI Lab - Nginx SSL</title>
</head>
<body>
    <h1>HTTPS - Nginx</h1>
    <p>Server: web01.vti.lab</p>
    <p>SSL: Self-Signed Certificate</p>
</body>
</html>
```

---

# 10. Tạo Nginx Virtual Host

```
sudo nano /etc/nginx/sites-available/web01.vti.lab
```

```
server {
    listen 80;
    server_name web01.vti.lab www.web01.vti.lab;

    return 301 https://web01.vti.lab$request_uri;
}

server {
    listen 443 ssl;
    server_name web01.vti.lab www.web01.vti.lab;

    root /var/www/web01.vti.lab;
    index index.html;

    ssl_certificate     /etc/nginx/ssl/web01.vti.lab.crt;
    ssl_certificate_key /etc/nginx/ssl/web01.vti.lab.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Enable:

```
sudo ln -s \
  /etc/nginx/sites-available/web01.vti.lab \
  /etc/nginx/sites-enabled/web01.vti.lab
```

---

# 11. Test Nginx

```
sudo nginx -t
```

Phải nhận:

```
syntax is ok
test is successful
```

Restart:

```
sudo systemctl restart nginx
```

Kiểm tra:

```
sudo systemctl status nginx
```

---

# 12. Kiểm tra HTTPS bằng OpenSSL

Từ client:

```
openssl s_client \
  -connect web01.vti.lab:443 \
  -servername web01.vti.lab
```

Hoặc:

```
openssl s_client \
  -connect web01.vti.lab:443 \
  -servername web01.vti.lab \
  2>/dev/null |
  openssl x509 \
  -noout \
  -subject \
  -issuer \
  -dates
```

---

# 13. Browser sẽ báo lỗi

Nếu truy cập:

```
https://web01.vti.lab
```

Browser có thể báo:

```
Your connection is not private
```

hoặc:

```
NET::ERR_CERT_AUTHORITY_INVALID
```

**Đây là hành vi bình thường.**

Certificate hợp lệ về mặt cryptographic nhưng client **không trust issuer**.

---

# PHẦN B — Windows IIS

## 14. Tạo Self-Signed Certificate bằng PowerShell

Trên Windows Server, mở:

**PowerShell → Run as Administrator**

Microsoft cung cấp `New-SelfSignedCertificate` trong PKI module để tạo self-signed certificate cho mục đích testing. Cmdlet này hỗ trợ `DnsName`, `KeyLength`, `HashAlgorithm`, `NotAfter`, certificate store... [Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate?view=windowsserver2025-ps&utm_source=chatgpt.com)

Chạy:

```
$cert = New-SelfSignedCertificate `
    -DnsName "web02.vti.lab","www.web02.vti.lab" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(1) `
    -FriendlyName "VTI Lab IIS SSL"
```

Kiểm tra:

```
$cert
```

---

# 15. Kiểm tra Certificate Store

```
Get-ChildItem Cert:\LocalMachine\My |
    Where-Object {$_.FriendlyName -eq "VTI Lab IIS SSL"}
```

Hoặc:

```
certlm.msc
```

Đi tới:

```
Certificates
   └── Local Computer
       └── Personal
           └── Certificates
```

Bạn sẽ thấy:

```
VTI Lab IIS SSL
```

---

# 16. Kiểm tra SAN

PowerShell:

```
$cert.Extensions |
    Where-Object {$_.Oid.FriendlyName -eq "Subject Alternative Name"}
```

Bạn phải thấy:

```
web02.vti.lab
www.web02.vti.lab
```

Microsoft cũng minh họa `New-SelfSignedCertificate -DnsName` để tạo certificate có Subject Alternative Names. [Microsoft Learn](https://learn.microsoft.com/de-at/powershell/module/pki/new-selfsignedcertificate?view=windowsserver2025-ps&utm_source=chatgpt.com)

---

# 17. Cài IIS

Nếu chưa có:

```
Install-WindowsFeature `
    -Name Web-Server `
    -IncludeManagementTools
```

Kiểm tra:

```
Get-WindowsFeature Web-Server
```

---

# 18. Tạo website IIS

Tạo thư mục:

```
New-Item `
    -Path "C:\inetpub\web02.vti.lab" `
    -ItemType Directory `
    -Force
```

Tạo HTML:

```
@"
<!DOCTYPE html>
<html>
<head>
    <title>VTI Lab IIS SSL</title>
</head>
<body>
    <h1>HTTPS - IIS</h1>
    <p>Server: web02.vti.lab</p>
    <p>SSL: Self-Signed Certificate</p>
</body>
</html>
"@ | Out-File `
    "C:\inetpub\web02.vti.lab\index.html" `
    -Encoding utf8
```

---

# 19. Tạo IIS Website

```
Import-Module WebAdministration
```

```
New-Website `
    -Name "web02.vti.lab" `
    -PhysicalPath "C:\inetpub\web02.vti.lab" `
    -Port 80 `
    -HostHeader "web02.vti.lab"
```

Kiểm tra:

```
Get-Website
```

---

# 20. Lấy Certificate Thumbprint

```
$cert = Get-ChildItem Cert:\LocalMachine\My |
    Where-Object {$_.FriendlyName -eq "VTI Lab IIS SSL"}

$cert.Thumbprint
```

Ví dụ:

```
A13F9B8C1234567890ABCDEF1234567890ABCDEF
```

---

# 21. Tạo HTTPS Binding

```
New-WebBinding `
    -Name "web02.vti.lab" `
    -Protocol https `
    -Port 443 `
    -HostHeader "web02.vti.lab"
```

Gắn certificate:

```
$thumbprint = $cert.Thumbprint

New-Item `
    "IIS:\SslBindings\0.0.0.0!443!web02.vti.lab" `
    -Thumbprint $thumbprint `
    -SSLFlags 1
```

Microsoft cũng hỗ trợ tạo HTTPS binding bằng PowerShell/IIS Administration và gắn certificate thông qua thumbprint. [Microsoft Learn](https://learn.microsoft.com/vi-vn/powershell/module/iisadministration/new-iissitebinding?view=windowsserver2025-ps&utm_source=chatgpt.com)

---

# 22. Kiểm tra IIS Binding

```
Get-WebBinding
```

Bạn muốn thấy:

```
protocol bindingInformation
https   *:443:web02.vti.lab
```

Hoặc kiểm tra:

```
netsh http show sslcert
```

---

# 23. Mở Firewall

```
New-NetFirewallRule `
    -DisplayName "HTTPS 443" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 443 `
    -Action Allow
```

---

# 24. Test IIS

Trên Windows:

```
curl.exe -k https://web02.vti.lab
```

Hoặc:

```
Invoke-WebRequest `
    https://web02.vti.lab `
    -SkipCertificateCheck
```

---

# 25. Trust Self-Signed Certificate

Đây là phần rất quan trọng nếu muốn browser **không cảnh báo**.

Có hai cách.

### Cách 1 — Import certificate vào Trusted Root

Export certificate:

```
Export-Certificate `
    -Cert $cert `
    -FilePath "C:\Temp\web02.vti.lab.cer"
```

Trên client:

```
certlm.msc
```

Import vào:

```
Trusted Root Certification Authorities
        └── Certificates
```

Sau đó restart browser.

---

# 26. Nhưng có một vấn đề với mô hình này

Nếu bạn có:

```
web01.vti.lab
web02.vti.lab
web03.vti.lab
web04.vti.lab
```

mà mỗi server tạo một self-signed certificate:

```
Client
 │
 ├── Trust web01 certificate
 ├── Trust web02 certificate
 ├── Trust web03 certificate
 └── Trust web04 certificate
```

sẽ rất khó quản lý.

Đây chính là lý do Enterprise PKI sử dụng:

```
                Root CA
                   │
            ┌──────┴──────┐
            │             │
       Intermediate    Intermediate
            │
       ┌────┼────┬────┐
       │    │    │    │
      Web  API  IIS  LDAP
```

Client chỉ cần:

```
Trust Root CA
```

thay vì trust từng server certificate.

---

```
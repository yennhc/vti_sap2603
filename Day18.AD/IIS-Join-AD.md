
⸻

LAB  - Build IIS Server và Join Domain vti.lab

Mô hình

                    Internet
                        |
                  192.168.100.1
                    pfSense
                        |
-----------------------------------------------------
|                    LAN 192.168.100.0/24           |
-----------------------------------------------------
DC1 (Primary DC)
192.168.100.2
DC2 (Secondary DC)
192.168.100.3
IIS01 (Windows Server 2022)
192.168.100.10

Domain

vti.lab

⸻

Phần 1. Chuẩn bị VM IIS01

Tạo VM

Item	Value
OS	Windows Server 2022
Hostname	IIS01
CPU	2 Core
RAM	4GB
Disk	60GB
Network	VMnet LAN

⸻

Đặt IP

IP Address
192.168.100.10
Subnet
255.255.255.0
Gateway
192.168.100.1
Preferred DNS
192.168.100.2
Alternate DNS
192.168.100.3

Quan trọng:

Không được dùng DNS 8.8.8.8

⸻

Phần 2. Kiểm tra DNS

Mở CMD

ping 192.168.100.2
ping dc1
ping dc2
nslookup dc1

Kết quả mong muốn

Name:
dc1.vti.lab
Address:
192.168.100.2

⸻

Kiểm tra Domain

nslookup vti.lab

Phải resolve được.

⸻

Phần 3. Join Domain

Mở

Server Manager
Local Server
Workgroup
Change

Chọn

Domain
vti.lab

Nhập

Username
Administrator
Password
********

Nếu thành công

Welcome to the vti.lab domain.

Restart server.

⸻

Phần 4. Kiểm tra Join Domain

Sau reboot

CMD

whoami

Đăng nhập

VTI\Administrator

Kiểm tra

systeminfo

Bạn sẽ thấy

Domain:
vti.lab

Hoặc PowerShell

(Get-CimInstance Win32_ComputerSystem).Domain

Kết quả

vti.lab

⸻

Phần 5. Kiểm tra AD

Trên DC1

Active Directory Users and Computers

Computers

IIS01

đã xuất hiện.

⸻

Phần 6. Cài IIS

Mở

Server Manager
Add Roles and Features

Chọn

Role-based installation

Chọn Server

IIS01

Tick

Web Server (IIS)

Tick luôn

Management Tools

Next

Install

⸻

Sau khi hoàn tất

Mở

http://localhost

Hiện

IIS Default Page

⸻

Phần 7. Tạo Website Demo

Tạo thư mục

C:\Websites
DemoSite

⸻

Tạo file

index.html

Nội dung

<!DOCTYPE html>
<html>
<head>
<title>VTI LAB</title>
</head>
<body>
<h1>Welcome to VTI LAB</h1>
<h2>IIS Server Joined Domain</h2>
<p>Hostname : IIS01</p>
<p>Domain : vti.lab</p>
<p>Administrator : Nguyen</p>
</body>
</html>

⸻

Phần 8. Tạo Website

Mở

Internet Information Services (IIS) Manager

Chuột phải

Sites
Add Website

Name

DemoSite

Physical Path

C:\Websites\DemoSite

Binding

HTTP
Port
80

Host name

demo.vti.lab

⸻

Phần 9. DNS Record

Trên DC1

Mở

DNS

Forward Lookup Zone

vti.lab

New Host

demo
192.168.100.10

Sẽ có

demo.vti.lab

⸻

Phần 10. Test

Trên IIS

ping demo.vti.lab
nslookup demo.vti.lab

Mở

http://demo.vti.lab

Trang demo sẽ hiển thị.

⸻

Phần 11. Firewall

Nếu không truy cập được

Windows Defender Firewall
Inbound Rules
World Wide Web Services (HTTP Traffic-In)
Enable

Hoặc

Enable-NetFirewallRule -DisplayGroup "World Wide Web Services (HTTP Traffic-In)"

⸻

Phần 12. Kiểm tra từ Client

Tạo thêm một VM Windows 11.

Join Domain.

Mở trình duyệt

http://demo.vti.lab

Hoặc

http://192.168.100.10

Trang web sẽ hiển thị.

⸻

Kiểm tra bằng PowerShell

hostname
whoami
ipconfig /all
Resolve-DnsName demo.vti.lab
Test-NetConnection demo.vti.lab -Port 80


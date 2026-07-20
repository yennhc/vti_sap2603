# Lab: Active Directory Domain Controller Redundancy (DHCP + DNS Replication)
**Windows Server 2019 Standard**

---

## 1. Tổng quan bài lab

| Hạng mục | Giá trị |
|---|---|
| Network | 192.168.99.0/24 |
| Subnet mask | 255.255.255.0 |
| Default Gateway | 192.168.99.1 *(giả định — chỉnh lại theo môi trường thật của bạn)* |
| Domain name | `vti.lab` *(có thể đổi tên khác tùy ý)* |
| NetBIOS name | `LAB` |
| DC-01 | 192.168.99.2 — DC đầu tiên (Forest root), DNS, DHCP |
| DC-02 | 192.168.99.3 — Additional DC, replicate DNS (qua AD-integrated zone) + DHCP (qua DHCP Failover) |
| DHCP Scope | 192.168.99.100 – 192.168.99.200 |

**Ghi chú quan trọng trước khi bắt đầu:**
- DNS sẽ **replicate tự động** vì zone là AD-integrated — không cần cấu hình gì thêm ngoài việc cài role DNS trên DC-02.
- DHCP **không tự replicate** như AD/DNS. Windows Server dùng tính năng **DHCP Failover** (Load Balance hoặc Hot Standby) để 2 DHCP server đồng bộ scope + lease. Đây là phần bạn cần cấu hình thủ công ở Phần 2.
- Thay `"Ethernet0"` trong các lệnh CLI bằng tên card mạng thật của bạn (`Get-NetAdapter` để xem).

---

## PHẦN 1 — DC-01: Domain Controller đầu tiên (Forest Root)

### 1.1. Cấu hình IP tĩnh

**UI:**
`Control Panel > Network and Sharing Center > Change adapter settings > click phải card mạng > Properties > Internet Protocol Version 4 (TCP/IPv4) > Properties`
- IP address: `192.168.100.2`
- Subnet mask: `255.255.255.0`
- Default gateway: `192.168.100.1`
- Preferred DNS server: `127.0.0.1` (chính nó, vì sắp làm DNS server)

**CLI:**
```powershell
Get-NetAdapter   # xem tên interface thật

New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.99.2 `
  -PrefixLength 24 -DefaultGateway 192.168.99.1

Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 127.0.0.1
```

### 1.2. Đổi tên máy

**UI:** `This PC > Properties > Advanced system settings > Computer Name > Change... > DC-01 > Restart`

**CLI:**
```powershell
Rename-Computer -NewName "DC-01" -Restart
```

### 1.3. Cài đặt role AD DS

**UI:** `Server Manager > Add Roles and Features > Server Roles > Active Directory Domain Services > Next > Install`

**CLI:**
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

### 1.4. Promote DC-01 thành Domain Controller (Forest mới)

**UI:** Sau khi cài xong role, click biểu tượng cờ vàng góc trên Server Manager → **Promote this server to a domain controller**
- Chọn **Add a new forest**
- Root domain name: `vti.lab`
- Forest/Domain functional level: Windows Server 2016 (tối đa cho 2019)
- Domain Controller Options: giữ nguyên (DNS server, Global Catalog được tick sẵn)
- Đặt DSRM password
- NetBIOS name: `VTI` (mặc định)
- Next → Next → **Install** (máy sẽ tự khởi động lại)

**CLI:**
```powershell
Install-ADDSForest `
  -DomainName "vti.lab" `
  -DomainNetbiosName "VTI" `
  -InstallDns:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
  -Force:$true
```
*(Máy sẽ tự động reboot sau khi hoàn tất.)*

### 1.5. Kiểm tra DNS zone tự tạo

**UI:** `dnsmgmt.msc > Forward Lookup Zones > vti.lab` (đã tự tạo kèm các record `_msdcs`, `_sites`, `_tcp`, `_udp`)

**CLI:**
```powershell
Get-DnsServerZone
```

### 1.6. Tạo Reverse Lookup Zone

**UI:** `DNS Manager > Reverse Lookup Zones > New Zone > Primary zone (AD-integrated) > Network ID: 192.168.100 > Allow only secure dynamic updates`

**CLI:**
```powershell
Add-DnsServerPrimaryZone -NetworkID "192.168.100.0/24" `
  -ReplicationScope "Forest" -DynamicUpdate "Secure"
```

### 1.7. Cài đặt role DHCP

**UI:** `Server Manager > Add Roles and Features > Server Roles > DHCP Server > Install`

**CLI:**
```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
```

### 1.8. Authorize DHCP trong AD

**UI:** Sau khi cài xong, hoàn tất wizard "DHCP Post-Install Configuration" → `DHCP console (dhcpmgmt.msc) > click phải server > Authorize`

*** Lưu ý: Cần phải login bằng tài khoản **Administrator** để có quyền authorize DHCP server***

**CLI:**
```powershell
netsh dhcp add securitygroups
Restart-Service DHCPServer
Add-DhcpServerInDC -DnsName "dc-01.vti.lab" -IPAddress 192.168.100.2
```

### 1.9. Tạo DHCP Scope

**UI:** `DHCP console > IPv4 > New Scope`
- Range: `192.168.100.100` – `192.168.100.200`
- Subnet mask: `255.255.255.0`
- Router (Default Gateway): `192.168.100.1`
- DNS server: `192.168.100.2`
- Domain name: `vti.lab`
- **Activate scope**

**CLI:**
```powershell
Add-DhcpServerv4Scope -Name "LAN-Scope" `
  -StartRange 192.168.100.100 -EndRange 192.168.100.200 `
  -SubnetMask 255.255.255.0 -State Active

Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 `
  -Router 192.168.100.1 -DnsServer 192.168.100.2 -DnsDomain "vti.lab"
```

### 1.10. Kiểm tra DC-01

```powershell
dcdiag /v
Get-ADDomainController
Get-DhcpServerv4Scope
```

---

## PHẦN 2 — DC-02: Additional Domain Controller (replicate AD/DNS + DHCP Failover)

```bash
#Reset machine ID
%WINDIR%\system32\sysprep\sysprep.exe /generalize /oobe /shutdown
```

### 2.1. Cấu hình IP tĩnh (trỏ DNS về DC-01 để có thể join domain)

**CLI:**
```powershell
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.100.3 `
  -PrefixLength 24 -DefaultGateway 192.168.100.1

Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.2
```

### 2.2. Đổi tên máy

**CLI:**
```powershell
Rename-Computer -NewName "DC-02" -Restart
```

### 2.3. Join domain (có thể bỏ qua bước này — Install-ADDSDomainController sẽ tự join)

**UI:** `System Properties > Change > Member of Domain: vti.lab > nhập VTI\Administrator + password > Restart`

**CLI:**
```powershell
$cred = Get-Credential VTI\Administrator
Add-Computer -DomainName "vti.lab" -Credential $cred -Restart
```

### 2.4. Cài đặt role AD DS

**CLI:**
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

### 2.5. Promote DC-02 làm Additional Domain Controller

**UI:** Click cờ vàng → **Add a domain controller to an existing domain**
- Domain: `vti.lab`
- Tick sẵn: **Domain Name System (DNS) server**, **Global Catalog (GC)**
- Site: Default-First-Site-Name
- DSRM password
- Replicate from: Any Domain Controller (hoặc chỉ định DC-01)
- Next → Next → **Install**

**CLI:**
```powershell
Install-ADDSDomainController `
  -DomainName "vti.lab" `
  -Credential (Get-Credential VTI\Administrator) `
  -InstallDns:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
  -Force:$true
```

> Bước này tự động replicate: AD database, SYSVOL, và toàn bộ DNS zone (vì zone là AD-integrated, scope Forest).

### 2.6. Kiểm tra AD Replication

**UI:** `Active Directory Sites and Services (dssite.msc) > Sites > Default-First-Site-Name > Servers > DC-02 > NTDS Settings` — xem connection object tới DC-01

**CLI:**
```powershell
repadmin /replsummary
repadmin /showrepl
dcdiag /v
Get-ADDomainController -Filter *
```

### 2.7. Kiểm tra DNS Replication

**CLI (chạy trên DC-02):**
```powershell
Get-DnsServerZone          # phải thấy vti.lab đã có sẵn
nslookup dc-01.vti.lab 192.168.100.3
```

Sau khi xác nhận DNS đã replicate, cập nhật lại DNS client trên cả 2 server để dùng cả 2 làm nhau dự phòng:

```powershell
# Trên DC-01
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.2,192.168.100.3

# Trên DC-02
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.3,192.168.100.2
```

### 2.8. Cài đặt role DHCP trên DC-02

**CLI:**
```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
netsh dhcp add securitygroups
Restart-Service DHCPServer
Add-DhcpServerInDC -DnsName "dc-02.vti.lab" -IPAddress 192.168.100.3
```

### 2.9. Cấu hình DHCP Failover — đây là bước "replicate" DHCP thật sự

DHCP không tự đồng bộ như AD/DNS. Tính năng **DHCP Failover** (từ Server 2012 R2 trở lên) cho phép 2 DHCP server chia sẻ và đồng bộ scope + lease theo thời gian thực.

**UI (thực hiện trên DC-01):**
`DHCP console > IPv4 > click phải scope "LAN-Scope" > Configure Failover...`
- Partner Server: `192.168.100.3`
- Relationship name: `DC01-DC02-Failover`
- Mode: **Load Balance** (chia 50/50 request) hoặc **Hot Standby** (1 server chính, 1 dự phòng)
- Shared Secret: đặt 1 password chung
- Finish → wizard sẽ tự động replicate scope config sang DC-02

**CLI (chạy trên DC-01) — chế độ Load Balance:**
```powershell
Add-DhcpServerv4Failover `
  -ComputerName "DC-01" `
  -PartnerServer "DC-02.vti.lab" `
  -Name "DC01-DC02-Failover" `
  -ScopeId 192.168.99.0 `
  -SharedSecret "P@ssw0rd123!" `
  -LoadBalancePercent 50 `
  -MaxClientLeadTime 01:00:00
```

**Hoặc chế độ Hot Standby** (DC-01 active, DC-02 standby):
```powershell
Add-DhcpServerv4Failover `
  -ComputerName "DC-01" `
  -PartnerServer "DC-02.vti.lab" `
  -Name "DC01-DC02-Failover" `
  -ScopeId 192.168.100.0 `
  -SharedSecret "P@ssw0rd123!" `
  -ServerRole Active `
  -ReservePercent 5
```

### 2.10. Kiểm tra Failover

**UI:** `DHCP console trên DC-02 > IPv4` — scope "LAN-Scope" sẽ tự xuất hiện, trạng thái Normal/Active tùy mode

**CLI:**
```powershell
Get-DhcpServerv4Failover
Get-DhcpServerv4Scope -ComputerName DC-02.vti.lab
Get-DhcpServerv4FailoverStatistics -ComputerName DC-01
```

---

## PHẦN 3 — Kiểm tra tổng thể & Test Case

1. **Join 1 client vào domain**, xin IP qua DHCP → `ipconfig /all` (kiểm tra IP, DNS suffix, DHCP server nào cấp)
2. **Test AD replication:** `repadmin /replsummary` trên cả 2 DC — không có lỗi
3. **Test DNS:** `nslookup dc-01.vti.lab 192.168.100.3` và ngược lại
4. **Test DHCP failover thật:** Tắt DC-01 (`Stop-Computer` hoặc shutdown VM) → client renew IP (`ipconfig /release && ipconfig /renew`) → vẫn nhận được IP từ DC-02
5. `Get-DhcpServerv4Lease -ComputerName DC-02.vti.lab` — kiểm tra lease được cấp từ DC-02 khi DC-01 down

---

## PHẦN 4 — Gợi ý mở rộng (tùy chọn)

- **FSMO roles:** `netdom query fsmo` — xem role nào đang nằm ở DC-01, có thể transfer 1 phần sang DC-02 để cân bằng tải (`Move-ADDirectoryServerOperationMasterRole`)
- **Time sync:** `w32tm /query /status` — đảm bảo 2 DC đồng bộ giờ (quan trọng cho Kerberos)
- **Sites and Services:** nếu mô phỏng multi-site, tạo thêm Site và Subnet object để kiểm soát replication topology
- **Group Policy replication (SYSVOL):** `dfsrmig /getglobalstate` (Server 2019 mặc định dùng DFSR, không cần cấu hình thêm)

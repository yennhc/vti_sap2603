# BÀI LAB: TRIỂN KHAI VPN SITE-TO-SITE TRÊN PFSENSE (IPSEC)

> **Ghi chú về nguồn tham khảo:** Bài lab này dựa trên kiến trúc và các bước cấu hình IPsec chuẩn của pfSense (áp dụng cho pfSense CE 2.7.x / pfSense Plus 24.x trở lên — dòng phiên bản mới nhất tính đến đầu 2026), triển khai trên **VMware Workstation Pro** (17.x trở lên — bản này Broadcom đã cho dùng miễn phí với mục đích cá nhân). Giao diện IPsec của pfSense và Virtual Network Editor của Workstation đều khá ổn định qua nhiều bản, tuy nhiên trước khi lên lớp, bạn nên đối chiếu nhanh với tài liệu chính thức tại **docs.netgate.com/pfsense/en/latest/vpn/ipsec/** để chắc chắn không có thay đổi vị trí menu ở bản pfSense/Workstation mà học viên đang dùng.

---

## 1. Giới thiệu & Kịch bản thực tế

Công ty **ABC Corp** có trụ sở chính (HQ) và một chi nhánh (Branch) ở hai địa điểm khác nhau. Hai văn phòng cần kết nối mạng nội bộ với nhau qua Internet công cộng để:

- Chia sẻ file server, máy in mạng, database nội bộ.
- Cho phép nhân viên chi nhánh truy cập ứng dụng nội bộ đặt tại HQ mà không cần public từng dịch vụ ra Internet.
- Đảm bảo dữ liệu truyền giữa 2 site được **mã hóa** (không đi dạng plaintext qua Internet).

Giải pháp: dựng **VPN Site-to-Site bằng IPsec** giữa 2 firewall pfSense đặt tại 2 site. Đây là kiến trúc được dùng rất phổ biến trong thực tế cho các doanh nghiệp vừa và nhỏ có nhiều chi nhánh.

## 2. Mục tiêu bài lab

Sau khi hoàn thành, học viên có thể:

1. Thiết kế sơ đồ địa chỉ IP cho mô hình 2 site.
2. Cấu hình interface WAN/LAN cơ bản trên pfSense.
3. Cấu hình đường hầm IPsec Phase 1 (IKE) và Phase 2 (IPsec SA) giữa 2 pfSense.
4. Viết firewall rule đúng để cho phép traffic đi qua tunnel.
5. Kiểm tra tunnel bằng Status, Packet Capture, và ping test thực tế.
6. Xử lý được các lỗi thường gặp nhất khi triển khai IPsec site-to-site trong môi trường thực tế (NAT, Outbound NAT, Private/Bogon network block...).

## 3. Kiến trúc & Sơ đồ mạng

Vì lab chạy trên VMware Workstation (không có 2 đường Internet thật), ta **giả lập Internet** bằng một mạng ảo **VMnet tùy chỉnh (Custom/Host-only)** trung gian, gán IP dạng "public giả lập" cho 2 cổng WAN. Cách cấu hình IPsec hoàn toàn giống hệt khi làm với IP public thật ngoài đời.

```
                    ┌────────────────────────────┐
                    │   "INTERNET" (giả lập)     │
                    │   VMnet4 (Custom): WAN-SIM  │
                    │      200.200.200.0/24       │
                    └───────────┬─────────┬───────┘
                     .10        │         │        .20
                ┌────────────┐  │         │   ┌────────────┐
                │  pfSense   │◄─┘         └──►│  pfSense   │
                │    HQ      │                │  Branch    │
                │  (WAN)     │◄── IPsec ──────►│  (WAN)     │
                │            │    Tunnel       │            │
                │  (LAN)     │                 │  (LAN)     │
                └─────┬──────┘                 └─────┬──────┘
                      │ .1                            │ .1
           192.168.100.0/24                  192.168.200.0/24
                      │                               │
                ┌─────┴──────┐                 ┌──────┴─────┐
                │  PC-HQ     │                 │ PC-Branch  │
                │ .100.10    │                 │  .200.10   │
                └────────────┘                 └────────────┘
```

> Trong triển khai thực tế: mỗi pfSense sẽ có WAN gắn IP public thật do ISP cấp (VD: HQ = 203.0.113.10, Branch = 198.51.100.20). Các bước cấu hình VPN **không đổi** — chỉ khác chỗ IP WAN là thật thay vì IP giả lập.

## 4. Chuẩn bị môi trường lab trên VMware Workstation

| Thành phần | Số lượng | Cấu hình tối thiểu | Ghi chú |
|---|---|---|---|
| pfSense VM | 2 | 2 vCPU, 2GB RAM, 20GB disk, 2 NIC | ISO pfSense CE 2.7.x trở lên |
| Client VM (test ping) | 2 | Ubuntu Server tối giản hoặc Windows, 1 vCPU, 1GB RAM | Chỉ cần 1 NIC |
| VMnet tùy chỉnh (Custom) | 3 | — | Tương ứng `WAN-SIM`, `LAN-HQ`, `LAN-Branch` |

### 4.1. Tạo 3 mạng ảo cô lập bằng Virtual Network Editor

VMware Workstation quản lý mạng ảo qua **Edit > Virtual Network Editor** (Windows cần mở Workstation với quyền Administrator mới sửa được; trên Linux dùng `sudo vmware-netcfg`). Mặc định máy đã có sẵn `VMnet0` (Bridged), `VMnet1` (Host-only), `VMnet8` (NAT) — ta **không dùng 3 mạng này** mà tạo mới để tránh xung đột với các VM khác đang chạy trên máy:

1. Mở **Virtual Network Editor** → **Change Settings** (yêu cầu quyền admin).
2. Nhấn **Add Network...**, chọn lần lượt `VMnet2`, `VMnet3`, `VMnet4`, mỗi lần add xong cấu hình như sau:

| VMnet | Vai trò | Connection type | DHCP | Subnet |
|---|---|---|---|---|
| VMnet2 | `LAN-HQ` | Host-only | **Tắt** (bỏ chọn "Use local DHCP service") | (không cần khai, PC/pfSense gán IP tĩnh) |
| VMnet3 | `LAN-Branch` | Host-only | **Tắt** | (không cần khai) |
| VMnet4 | `WAN-SIM` | Host-only | **Tắt** | (không cần khai) |

> Chọn **Host-only**, không chọn **NAT** — vì mạng WAN-SIM ở đây cần là một đoạn L2 kín hoàn toàn (không có route ra Internet thật, không NAT tự động của VMware), giống một liên kết point-to-point/ISP segment thuần túy để tự tay cấu hình VPN. Nếu chọn NAT, VMware sẽ tự chèn thêm gateway 8/router ảo gây sai lệch mô hình lab.
> Cũng nên **bỏ chọn "Connect a host virtual adapter to this network"** cho cả 3 VMnet, để máy host Windows/Linux không tự nhảy vào các mạng lab này.

### 4.2. Tạo VM pfSense-HQ và pfSense-Branch

Với mỗi VM pfSense, dùng **New Virtual Machine Wizard** (Typical hoặc Custom đều được):

1. Chọn **"I will install the operating system later"**, rồi vào **VM Settings > CD/DVD** để mount file ISO pfSense đã tải sẵn.

> **Lưu ý quan trọng — bước "Connectivity Check" khi cài:** Bộ cài Netgate/pfSense bản mới có bước tự kiểm tra Internet ("Verifying the Internet connection... Trying to reach the Netgate Servers"). Vì VM sẽ được gắn vào VMnet cô lập (không có Internet) theo thiết kế lab, bước này có thể treo rất lâu. Cách xử lý: **tạm thời** đổi Network Adapter của VM sang **NAT** (VD `VMnet8` có sẵn của Workstation) chỉ trong lúc cài OS để vượt qua bước check này; sau khi cài xong và pfSense reboot vào màn hình console, **tắt VM và đổi lại Network Adapter về đúng VMnet theo mục 4.4** trước khi làm bước Assign Interfaces.
2. **Guest OS**: chọn **"FreeBSD" → "FreeBSD 14 version (64-bit)"** (nếu bản Workstation chưa có FreeBSD 14 trong danh sách, chọn bản FreeBSD 64-bit gần nhất — không ảnh hưởng vì đây chỉ là gợi ý driver/tối ưu, không phải điều kiện bắt buộc).
3. **CPU/RAM**: 2 vCPU, 2GB RAM.
4. **Disk**: 20GB, "Store virtual disk as a single file".
5. Vào **VM Settings > Network Adapter** (adapter có sẵn) → đổi thành **Custom: VMnet4 (WAN-SIM)**.
6. **Add... > Network Adapter** để thêm NIC thứ 2 → chọn **Custom: VMnet2 (LAN-HQ)** cho pfSense-HQ, hoặc **VMnet3 (LAN-Branch)** cho pfSense-Branch.
7. Với cả 2 Network Adapter, vào **Advanced...** đổi **Adapter type** thành **E1000** (thay vì mặc định e1000e/vmxnet3). E1000 cho tên interface dễ đoán (`em0`, `em1`) và tương thích ổn định nhất với bước "Assign Interfaces" của pfSense.
8. Bật **"Connect at power on"** cho cả 2 adapter.
9. Đặt tên VM rõ ràng: `pfSense-HQ`, `pfSense-Branch` để tránh nhầm khi có nhiều VM đang mở trong Workstation.

> **Mẹo thực tế:** Chụp **Snapshot** (VM > Snapshot > Take Snapshot) ngay sau khi cài xong pfSense nhưng trước khi cấu hình IPsec — nếu học viên cấu hình sai và muốn làm lại từ đầu, chỉ cần Revert Snapshot thay vì cài lại từ ISO.

### 4.3. Tạo VM PC-HQ và PC-Branch (máy test)

- Guest OS: Ubuntu Server (khuyến nghị, nhẹ) hoặc Windows.
- 1 Network Adapter duy nhất: `PC-HQ` → **Custom: VMnet2 (LAN-HQ)**, `PC-Branch` → **Custom: VMnet3 (LAN-Branch)**.
- Adapter type: mặc định (e1000e/vmxnet3) đều được vì không liên quan tới việc "Assign Interfaces" của pfSense.

### 4.4. Bảng đấu nối tổng hợp

| VM | Adapter 1 | Adapter 2 |
|---|---|---|
| `pfSense-HQ` | VMnet4 (WAN-SIM) → **WAN** | VMnet2 (LAN-HQ) → **LAN** |
| `pfSense-Branch` | VMnet4 (WAN-SIM) → **WAN** | VMnet3 (LAN-Branch) → **LAN** |
| `PC-HQ` | VMnet2 (LAN-HQ) | — |
| `PC-Branch` | VMnet3 (LAN-Branch) | — |

## 5. Bảng quy hoạch địa chỉ IP

| Site | Interface | IP | Ghi chú |
|---|---|---|---|
| HQ | WAN | 200.200.200.10/24 | "Public giả lập" |
| HQ | LAN | 192.168.100.1/24 | Gateway cho PC-HQ |
| HQ | LAN range | 192.168.100.0/24 | Mạng cần bảo vệ qua VPN |
| Branch | WAN | 200.200.200.20/24 | "Public giả lập" |
| Branch | LAN | 192.168.200.1/24 | Gateway cho PC-Branch |
| Branch | LAN range | 192.168.200.0/24 | Mạng cần bảo vệ qua VPN |
| PC-HQ | — | 192.168.100.10/24, GW 192.168.100.1 | |
| PC-Branch | — | 192.168.200.10/24, GW 192.168.200.1 | |

---

## 6. PHẦN A — Cấu hình cơ bản pfSense-HQ

1. Cài đặt pfSense trên VM (boot từ ISO đã mount ở bước 4.2), sau khi cài xong pfSense sẽ reboot vào console. Với adapter E1000 đã chọn ở mục 4.2, 2 NIC sẽ hiện là `em0` và `em1`.
2. Ở màn hình console, chọn **Assign Interfaces**:
   - Gán **WAN** = `em0` (adapter nối VMnet4/WAN-SIM — thường là adapter add vào trước tiên).
   - Gán **LAN** = `em1` (adapter nối VMnet2/LAN-HQ).
   - Nếu không chắc NIC nào là NIC nào, dùng chức năng auto-detect của pfSense (rút dây/ngắt kết nối từng adapter trong VM Settings để pfSense tự nhận diện) hoặc đối chiếu MAC address hiển thị trong VM Settings > Network Adapter với MAC hiển thị ở bước Assign Interfaces.
3. Vào console option **2) Set interface(s) IP address**:
   - WAN: `200.200.200.10`, subnet `/24`, không cần gateway riêng (dùng chung dải giả lập) — trong thực tế đây sẽ là gateway của ISP.
   - LAN: `192.168.100.1`, subnet `/24`.
4. Truy cập WebGUI qua `https://192.168.100.1` từ PC-HQ, đăng nhập `admin` `pfsense` / mật khẩu đã đặt lúc cài.
5. Vào **Interfaces > WAN**:
   - Bỏ chọn **Block private networks and loopback addresses**.
   - Bỏ chọn **Block bogon networks**.
   
   > *Lý do:* Vì ta dùng dải `200.200.200.0/24` để giả lập Internet trong lab (không phải IP public thật), pfSense sẽ mặc định chặn các gói tin nếu dải này rơi vào danh sách bogon/private tùy cấu hình. **Trong triển khai thực tế với IP public thật, hai tùy chọn này thường được giữ nguyên (bật) để tăng bảo mật** — chỉ tắt trong môi trường lab.
6. Đặt hostname dễ phân biệt: **System > General Setup** → Hostname: `pfsense-hq`.

## 7. PHẦN B — Cấu hình cơ bản pfSense-Branch

Lặp lại tương tự Phần A cho pfSense thứ 2:

- WAN: `200.200.200.20/24`
- LAN: `192.168.200.1/24`
- Hostname: `pfsense-branch`
- Bỏ chọn **Block private networks** và **Block bogon networks** trên WAN (cùng lý do như trên).

Kiểm tra nhanh: từ `pfsense-hq` (Diagnostics > Ping), ping thử `200.200.200.20` — phải thành công trước khi qua bước cấu hình IPsec.

---

## 8. PHẦN C — Cấu hình IPsec Phase 1 tại HQ

Vào **VPN > IPsec > Tunnels > Add P1**.

| Trường | Giá trị |
|---|---|
| Key Exchange version | IKEv2 |
| Internet Protocol | IPv4 |
| Interface | WAN |
| Remote Gateway | `200.200.200.20` (WAN của Branch) |
| Description | `IPSEC-to-Branch` |

**Phase 1 Proposal (Authentication):**

| Trường | Giá trị |
|---|---|
| Authentication Method | Mutual PSK |
| My identifier | My IP address |
| Peer identifier | Peer IP address |
| Pre-Shared Key | Chuỗi mạnh, VD: `Sxk9!Tv2#Qm7Lp4z` (sinh bằng `openssl rand -base64 24`) |

**Phase 1 Proposal (Algorithms):**

| Trường | Giá trị |
|---|---|
| Encryption Algorithm | AES 256 |
| Hash Algorithm | SHA256 |
| DH Group | 14 (2048-bit) |
| Lifetime | 28800 |

**Advanced Options:**

| Trường | Giá trị |
|---|---|
| NAT Traversal | Auto |
| Dead Peer Detection | Enable, Delay = 10s, Max failures = 5 |

Nhấn **Save**.

## 9. PHẦN D — Cấu hình IPsec Phase 2 tại HQ

Trong tunnel vừa tạo, nhấn **Add P2**.

| Trường | Giá trị |
|---|---|
| Mode | Tunnel IPv4 |
| Local Network | Network: `192.168.100.0/24` |
| Remote Network | Network: `192.168.200.0/24` |

**Phase 2 Proposal (SA/Key Exchange):**

| Trường | Giá trị |
|---|---|
| Protocol | ESP |
| Encryption Algorithms | AES 256 |
| Hash Algorithms | SHA256 |
| PFS key group | 14 |
| Lifetime | 3600 |

Nhấn **Save** → **Apply Changes**.

---

## 10. PHẦN E — Cấu hình IPsec tại Branch (đối xứng)

Vào **VPN > IPsec > Tunnels > Add P1** trên `pfsense-branch`, cấu hình **giống hệt HQ** ngoại trừ:

| Trường | Giá trị (Branch) |
|---|---|
| Remote Gateway | `200.200.200.10` (WAN của HQ) |
| Description | `IPSEC-to-HQ` |
| Pre-Shared Key | **Phải giống hệt PSK đã đặt ở HQ** |

Tất cả thông số Encryption/Hash/DH Group/Lifetime ở Phase 1 và Phase 2 **phải khớp tuyệt đối** với bên HQ, IPsec sẽ không lên nếu 2 bên đề xuất thuật toán khác nhau.

Phase 2 tại Branch — chú ý **network bị đảo ngược**:

| Trường | Giá trị |
|---|---|
| Local Network | `192.168.200.0/24` |
| Remote Network | `192.168.100.0/24` |

Save → Apply Changes.

## 11. PHẦN F — Cấu hình Firewall Rules (bước hay bị bỏ sót nhất)

### 11.1. Rule trên WAN (cả 2 site)

Vào **Firewall > Rules > WAN**, thêm rule cho phép negotiation IPsec đến từ IP của peer:

| # | Protocol | Source | Port đích | Mục đích |
|---|---|---|---|---|
| 1 | UDP | Peer WAN IP | 500 | ISAKMP/IKE |
| 2 | UDP | Peer WAN IP | 4500 | NAT-T |
| 3 | ESP | Peer WAN IP | — | Dữ liệu đã mã hóa |

> pfSense có cơ chế ngầm hỗ trợ một phần traffic IPsec, nhưng để đảm bảo hoạt động ổn định và dễ audit, **luôn tạo rule tường minh** như trên — đây cũng là cách làm chuẩn trong môi trường production.

### 11.2. Rule trên tab "IPsec" (bắt buộc — nếu thiếu, tunnel lên nhưng KHÔNG ping được)

Sau khi bật IPsec, một tab **IPsec** mới xuất hiện tại **Firewall > Rules**. Thêm rule tại **cả 2 site**:

| Trường | Giá trị |
|---|---|
| Action | Pass |
| Interface | IPsec |
| Source | LAN subnet của chính site đó (VD ở HQ: `192.168.100.0/24`) |
| Destination | Any (hoặc LAN subnet phía đối diện) |
| Protocol | Any |

### 11.3. Kiểm tra Outbound NAT (lỗi kinh điển trong thực tế)

Nếu pfSense đang ở chế độ **Manual Outbound NAT** (Firewall > NAT > Outbound), traffic đi đến mạng LAN phía bên kia **không được NAT** ra IP WAN — nếu không, gói tin sẽ mất định danh subnet gốc và tunnel sẽ không match Phase 2. Ở chế độ **Automatic Outbound NAT** (mặc định), pfSense tự loại trừ traffic này nên thường không cần chỉnh — nhưng đây là nguyên nhân số 1 khiến "Phase 2 up nhưng không ping được" trong triển khai thực tế, cần luôn kiểm tra khi troubleshoot.

---

## 12. PHẦN G — Kiểm tra & Kiểm thử

1. **Status > IPsec** (cả 2 site): Phase 1 và Phase 2 phải hiện màu xanh (Established / Connected).
2. Từ `PC-HQ` (192.168.100.10):
   ```
   ping 192.168.200.10
   ```
   Kết quả mong đợi: reply thành công, không mất gói.
3. Kiểm tra ngược lại từ `PC-Branch` → `192.168.100.10`.
4. **Diagnostics > Packet Capture** trên interface WAN của HQ, filter theo peer IP, sẽ thấy các gói ESP (protocol 50) thay vì ICMP thô — chứng minh traffic đã được mã hóa qua tunnel chứ không đi thẳng.
5. **Status > IPsec > Overview** → xem cột "Bytes In/Out" tăng lên sau khi ping — xác nhận dữ liệu thực sự chạy qua tunnel.

## 13. PHẦN H — Xử lý sự cố thường gặp

| Triệu chứng | Nguyên nhân khả dĩ | Cách khắc phục |
|---|---|---|
| Phase 1 không lên, log báo "no matching proposal" | Encryption/Hash/DH Group 2 bên không khớp | Đối chiếu lại từng thông số Phase 1 giữa 2 site |
| Phase 1 không lên, log báo "authentication failed" | PSK sai/không khớp | Nhập lại PSK giống hệt 2 bên (copy-paste, tránh gõ tay) |
| Không ping xuyên site được dù Phase 1/2 đã Established | Thiếu rule trên tab **IPsec** | Thêm rule Firewall > Rules > IPsec như mục 11.2 |
| Ping được 1 chiều, chiều còn lại không | Rule tường lửa chỉ set 1 chiều, hoặc thiếu route ngược | Kiểm tra rule + Phase 2 network ở cả 2 site |
| Phase 1 không negotiate được dù ping WAN-to-WAN OK | Rule UDP 500/4500 trên WAN bị chặn | Kiểm tra mục 11.1 |
| Tunnel tự rớt sau vài phút | Lifetime lệch nhau hoặc DPD quá nhạy | Đồng bộ lifetime 2 bên, chỉnh DPD delay |
| pfSense chặn hết traffic từ peer dù đã mở rule | "Block private networks/bogon" đang bật trên WAN (chỉ xảy ra trong lab dùng IP giả lập) | Tắt 2 tùy chọn này trên WAN như mục 6 bước 5 |
| 2 pfSense không ping thấy nhau qua WAN-SIM dù đã cấu hình đúng IP | VM đang gắn nhầm VMnet, hoặc adapter chưa "Connect at power on", hoặc Virtual Network Editor chưa Apply | Kiểm tra lại VM Settings > Network Adapter của từng VM đúng VMnet2/3/4 như bảng mục 4.4; mở lại Virtual Network Editor, bấm **Apply**/**OK** rồi restart VM |

## 14. PHẦN I — Mở rộng: Góc nhìn thực tế production

- **PSK vs Certificate:** PSK dễ triển khai cho lab, nhưng trong môi trường production nhiều site nên dùng **xác thực bằng certificate** (VPN > IPsec > Certificates), tránh rủi ro rò rỉ khóa dùng chung.
- **Redundancy:** Với 2 site quan trọng, nên cấu hình **Dual WAN + Gateway Groups** để tunnel tự chuyển sang đường truyền dự phòng khi WAN chính rớt.
- **Giám sát:** Có thể đẩy trạng thái IPsec (`ipsec statusall`) hoặc log vào Zabbix/Grafana để cảnh báo khi tunnel down — phù hợp mô hình giám sát hạ tầng đã có sẵn.
- **Thay thế hiện đại hơn:** pfSense từ bản 2.7.0 trở đi hỗ trợ **WireGuard** dạng native (VPN > WireGuard) — cấu hình đơn giản hơn IPsec, hiệu năng tốt, phù hợp cho site-to-site nếu không bắt buộc dùng chuẩn IPsec (VD: do yêu cầu tuân thủ hoặc tương thích thiết bị khác hãng).
- **Từ lab sang thật:** Khi mang mô hình này ra thiết bị/VM thật (không còn giả lập trong VMware Workstation), chỉ cần đổi adapter WAN từ **Custom: VMnet4** sang **Bridged** (trỏ ra NIC vật lý có Internet) và thay IP giả lập `200.200.200.x` bằng IP public thật do ISP cấp — toàn bộ phần cấu hình IPsec (Phase 1, Phase 2, firewall rule) giữ nguyên không đổi.

## 15. Checklist hoàn thành bài lab

- [ ] Interface WAN/LAN cấu hình đúng trên cả 2 pfSense
- [ ] Phase 1 hiển thị Established ở cả 2 chiều
- [ ] Phase 2 hiển thị Connected, có route cho subnet đối diện
- [ ] Rule Firewall trên tab IPsec đã thêm ở cả 2 site
- [ ] Ping thành công 2 chiều giữa PC-HQ và PC-Branch
- [ ] Packet capture xác nhận traffic đi qua ESP, không phải plaintext
- [ ] Restart pfSense và xác nhận tunnel tự thiết lập lại

## 16. Tài liệu tham khảo

- Netgate pfSense Documentation — IPsec: `docs.netgate.com/pfsense/en/latest/vpn/ipsec/`
- RFC 7296 — Internet Key Exchange Protocol Version 2 (IKEv2)
- Netgate pfSense Documentation — WireGuard: `docs.netgate.com/pfsense/en/latest/vpn/wireguard/`

> **Lưu ý:** Dữ liệu huấn luyện của mình dừng ở đầu năm 2026, nên số phiên bản pfSense cụ thể hoặc vị trí menu có thể đã thay đổi nhẹ tính đến thời điểm bạn dạy lab. Nếu cần số liệu/phiên bản chính xác tuyệt đối tại thời điểm hiện tại, bạn có thể bật tính năng tìm kiếm web hoặc kiểm tra trực tiếp trên trang Netgate trước khi đưa vào slide.

# D3 — Làm lại D2 bằng Azure CLI · bắt đầu 2026-09-16 12:14

> AI-OFF: **tự tra docs**, không nhờ AI viết lệnh. AI chỉ giải thích khái niệm và đọc lỗi.
> ⚠️ Tạo resource thật (~$0.12/giờ khi cả plan P0V3 + MySQL chạy). Xoá RG cuối buổi.

Trạng thái đầu bài (CLI 12:14): đã đăng nhập `Azure subscription 1`, tenant `vinuni.edu.vn`; không có RG nào của dự án (chỉ `DefaultResourceGroup-SEA` rỗng).

## Quy ước hôm nay

| Resource | Tên |
|---|---|
| Resource group | `rg-d3-cli` |
| MySQL Flexible | `mysql-d3-<hậu tố>` |
| App Service Plan | `asp-d3-cli` |
| Web App | `app-d3-<hậu tố>` |
| Slot | `staging` |

Mật khẩu MySQL: **không gõ thẳng vào dòng lệnh** (nó vào `~/.zsh_history`). Dùng biến môi trường đọc từ prompt ẩn, hoặc để CLI tự hỏi.

## Tiến độ

- [x] 0. Azure CLI **2.90.0** (extension `scheduled-query`), đúng subscription
- [x] 1. RG `rg-d3-cli` (southeastasia) — CLI bắt khai báo `--location`, Portal chỉ chọn dropdown
- [x] 2. MySQL `mysql-d3-3082` — **5 phút 37 giây**, tạo lúc 13:51
  - CLI in ra 3 thứ Portal giấu: `IOPS is 360` (miễn phí theo storage+SKU, thêm thì $0.06/IOPS-tháng) · `(Paid Tier)` · tự tạo firewall rule `FirewallIPAddress_2026-9-16_13-51-25` cho IP `113.185.x.x`
  - `--database-name d3test` tạo sẵn database; ở D2 phải tự `CREATE DATABASE` bằng SQL
  - IP đổi 3 lần trong ngày: 113.185.x.x → 59.153.x.x → 113.185.x.x
- [x] 3. App Service Plan `asp-d3-cli` (Linux, P0V3) — **8.6 giây**
- [x] 4. Web App `app-d3-3082` — **42 giây**, `HTTP 200`; tổng cả 3 resource ~6 phút (Portal D2 mất ~2 tiếng cả thao tác)
- [x] 5. Outbound IPs: **current 7 / possible 20** (đếm bằng `-o tsv | tr ',' '\n' | wc -l`; JMESPath không có `split()`)
- [x] 6. Vòng lặp shell tạo **20 firewall rule** (tên `app-<ip-gạch-ngang>`, vì tên rule không cho dấu chấm) → tổng **21 rule** = 20 app + 1 client IP
  - 20 lần gọi API riêng biệt; Portal phải gõ tay 20 dòng
  - Script chỉ **thêm**, không bao giờ **xoá** rule thừa khi danh sách possible đổi → rác tích tụ, không biết rule nào còn dùng
- [x] 7. Access restriction (15:52) — `allow-my-ip 116.98.x.x/32 Allow 100` + `Deny all` mặc định
  - Main site **200** từ IP mình ✅ · **SCM/Kudu 403 kể cả với mình** ⚠️
  - Lý do: `scmIpSecurityRestrictionsUseMain = false` và danh sách SCM **chỉ có Deny all**, không có rule allow nào. Portal D2 tick sẵn *Use main site rules*; CLI thì phải khai `--use-same-restrictions-for-scm-site true`
  - → nếu CD deploy qua Kudu sẽ gãy mà không rõ lý do (bài học cho D16)
- [x] 8. Slot `staging` + swap
  - `--configuration-source app-d3-3082` = "Clone settings from" của Portal; slot clone được cả `httpsOnly=true`
  - Gán image bằng `az webapp config container set --slot staging`
  - **Swap mất 1 phút 05 giây**
- [x] 9. Scale out: `--number-of-workers 2` → `sku.capacity = 2` → về 1. P0V3 cho tối đa **30 instance**
- [x] 10. Thí nghiệm idempotency — xem bảng bên dưới
- [x] 11. Xoá RG `rg-d3-cli` lúc **16:07** bằng `az group delete --yes --no-wait` — CLI trả điều khiển **ngay lập tức**, xoá chạy nền; 16:09 kiểm tra: 0 RG dự án, 0 resource, 0 plan, 0 MySQL ✅
  - Khác Portal: Portal bắt gõ lại tên để xác nhận và hiện thanh tiến trình; CLI chỉ cần `--yes` → **nhanh hơn nhưng dễ xoá nhầm hơn**
  - Môi trường sống 13:45 → 16:07 ≈ **2h20 ≈ $0.28**

**D3 hoàn thành 2026-09-16 16:09.** Tổng D2 + D3 ≈ $0.6.

## Lệnh đã dùng

Với mỗi bước ghi: lệnh · từng tham số nghĩa là gì · tham số nào Portal đã tự điền hộ ở D2.

### 0. Kiểm tra môi trường
```bash
```

### 1. Resource group
```bash
```

## Thí nghiệm idempotency

| Lệnh chạy lần 2 | Kết quả | Loại hành vi |
|---|---|---|
| `az group create` | im lặng thành công, không lỗi | idempotent thật (PUT theo tên) |
| `az mysql flexible-server firewall-rule create` (rule đã có) | trả về rule bình thường, tổng vẫn **21** | idempotent, ghi đè cùng giá trị |
| `az webapp create` (app đã có) | cảnh báo nhẹ *"Webapp already exists. The command will use the existing app's settings"* nhưng **`httpsOnly` bị reset true → false** | ⚠️ **nguy hiểm nhất**: exit code 0, không lỗi, nhưng âm thầm hạ cấu hình bảo mật |
| Sửa tay `--always-on false` rồi `show` | CLI trả giá trị mới, **không hề biết là "lệch"** | script không có khái niệm trạng thái mong muốn |

**Bằng chứng ghi nhận 16:05:** production `httpsOnly = False`, slot staging `httpsOnly = True` (slot clone lúc production còn true ⇒ loại trừ nguyên nhân do swap).

**Kết luận cho GATE D10:** script CLI *tạo được* hạ tầng nhưng không *giữ được* hạ tầng. Terraform so code với state nên `apply` lần hai in "No changes", và mọi thay đổi tay đều hiện ra ở `plan`.

## So với D2: Portal đã giấu gì

| Thuộc tính | Portal (D2) | CLI (D3) | Hệ quả |
|---|---|---|---|
| Hostname | `app-d2-3082-bub3cceqadf8aqaf…` (bật *Secure unique default hostname*) | `app-d3-3082.azurewebsites.net`, **không hậu tố** | Portal thêm hậu tố ngẫu nhiên chống dò tên; CLI thì không → tên dễ bị đoán/chiếm |
| `httpsOnly` | **true** | **false** | CLI mặc định **kém an toàn hơn**; phải `az webapp update --https-only true` |
| `alwaysOn` | false (phải bật tay) | **true** | ngược lại với Portal |
| `linuxFxVersion` | `sitecontainers` (mô hình mới) | `DOCKER|mcr.microsoft.com/…` (mô hình cũ) | **hai mô hình container khác nhau** — giải thích vì sao ở D2 clone slot không mang theo image |
| `ftpsState` | FtpsOnly | FtpsOnly | giống |
| `minTlsVersion` | 1.2 | 1.2 | giống |
| `healthCheckPath` | null | null | cả hai đều không tự bật → D17 phải khai báo |
| Tier plan | tự chọn **B1** khi không sửa Pricing plan | phải ghi rõ `--sku P0V3` | CLI không đoán hộ |
| Tên plan | tự sinh `ASP-rgd2manual-8c56` | do mình đặt `asp-d3-cli` | |
| Database MySQL | phải tự `CREATE DATABASE` | `--database-name` tạo sẵn | |
| Firewall client IP | ô tick lúc tạo | `--public-access <IP>` | cả hai đều chụp IP tại thời điểm chạy |
| Backup retention | mặc định 7 ngày | `--backup-retention 1` | CLI cho kiểm soát, Portal giấu trong Dev/Test |

## Lỗi gặp và cách xử lý

| Lỗi (nguyên văn rút gọn) | Nguyên nhân | Cách sửa |
|---|---|---|
| `argument --name/-n: expected one argument` | biến `$RG` rỗng — khối `export` chạy ở terminal khác | đặt lại biến trong đúng terminal; `echo` kiểm tra trước khi chạy |
| `(InvalidAdminLoginPassword) The AdministratorLoginPassword cannot be empty or null` | `$MYSQL_PW` rỗng — chỉ chạy khối `export`, chưa chạy `read` | `read -s`, kiểm tra bằng `${#MYSQL_PW}` (in độ dài, không in giá trị) |

## Sự cố bảo mật (ghi để cross-review)

`az mysql flexible-server create` **in mật khẩu admin dạng chữ thường ra stdout** (trường `password` và `connectionString`). Output đó đã đi vào scrollback terminal và bị dán vào chat AI.

- Quyết định 2026-09-16: **không xoay vòng mật khẩu**, vì server `mysql-d3-3082` sẽ bị xoá trong ngày cùng RG. Rủi ro giới hạn trong vài giờ, dữ liệu là dữ liệu thử.
- Nếu là môi trường sống thì phản xạ đúng là **đổi mật khẩu ngay** (`az mysql flexible-server update -p …`), vì secret đã ra khỏi vùng kiểm soát.
- Cách phòng: thêm `-o none` cho lệnh tạo; khi copy output luôn bỏ dòng chứa `password`, `connectionString`, `key`, `token`.
- Từ D9, mật khẩu do `random_password` sinh và nằm trong Key Vault, không ai đọc bằng mắt nữa.

## Tự kiểm tra
1. Portal, CLI, Terraform giống nhau ở điểm nào?
2. Vì sao chạy lại script CLI thường lỗi, còn `terraform apply` lần hai là "No changes"?
3. Tham số nào của MySQL nếu để mặc định sẽ tốn tiền hơn cần thiết?

# D8 — Terraform: App Service + MySQL

**Cần:** D7 · **Chi phí:** ~$0.12/giờ khi đang apply — **destroy cuối buổi** · **Nhật ký:** `notes/d8.md`

## Mục tiêu
Viết Terraform cho phần compute và DB, apply ra đúng những gì D2 làm tay — lần này có thể xoá và dựng lại.

## 1. Chia file trong `infra/app`

| File | Chứa |
|---|---|
| `versions.tf` / `providers.tf` / `backend.tf` | từ D7 |
| `variables.tf` · `locals.tf` · `outputs.tf` | biến, tên, tag, output |
| `identity.tf` | user-assigned managed identity |
| `app.tf` | App Service Plan, Web App, slot |
| `db.tf` | MySQL Flexible, database, firewall |

## 2. Managed identity
- `id-vsf-app-<hậu tố>` trong `rg-vsf-dev`.
- Output: `id`, `client_id`, `principal_id` — ghi vào note mỗi giá trị dùng ở đâu (gắn vào app · pull ACR · Key Vault reference · role assignment).

## 3. App Service Plan + Web App + slot

| Thành phần | Cấu hình cần đạt | Lý do / yêu cầu |
|---|---|---|
| Plan | Linux · **P0v3** · 1 worker | Slot + autoscale (M2, M7) |
| Web App | tên `app-vsf-<hậu tố>` · **HTTPS only** · TLS tối thiểu 1.2 · FTP tắt · HTTP/2 bật · **always on** bật | Cơ bản bảo mật + tránh cold start |
| Identity | **user-assigned** = identity ở bước 2 | M1, M4 |
| Container | image **placeholder công khai** (ví dụ image mẫu của App Service) | ACR chưa có ở bài này |
| App settings | cổng app (`WEBSITES_PORT`) · tắt lưu trữ dùng chung nếu không cần | |
| Health check | path `/health` (bật ở D17 khi app thật đã chạy — placeholder không có `/health`) | |
| Slot `staging` | **cùng** identity, cùng cấu hình site | Swap không đổi danh tính |

## 4. MySQL Flexible

| Thuộc tính | Giá trị | Ghi chú |
|---|---|---|
| Tên | `mysql-vsf-<hậu tố>` | duy nhất toàn cầu |
| SKU | Burstable **B1ms** | |
| Phiên bản | 8.0 (bản cụ thể Portal đang cho) | |
| Storage | 20 GiB, auto-grow tắt | tránh tăng tiền ngoài ý muốn |
| Backup retention | **1 ngày** (tối thiểu), geo-redundant backup **tắt** | tiết kiệm (M7) |
| High availability | tắt | |
| Admin user | `vsfadmin` | |
| Admin password | resource `random_password` (độ dài ≥ 24, **giới hạn ký tự đặc biệt** tránh ký tự phá connection string) | nằm trong state → state storage phải được bảo vệ |
| Availability zone | để Azure chọn rồi **bỏ qua thay đổi zone** | tránh plan luôn báo thay đổi |
| Database | `appdb`, charset utf8mb4 | |

## 5. Firewall theo outbound IPs — bẫy lớn nhất của bài

Mục tiêu: một firewall rule cho **mỗi IP** trong danh sách *possible outbound IPs* của Web App.

**Vấn đề:** lần apply đầu tiên, Web App chưa tồn tại → danh sách IP **chưa biết lúc plan** → Terraform từ chối `for_each` (lỗi *Invalid for_each argument… cannot be determined until apply*).

**Các cách xử lý — chọn một, ghi Decision:**

| Cách | Mô tả | Ưu | Nhược |
|---|---|---|---|
| **Apply 2 pha tự động** | Makefile chạy apply giới hạn vào Web App trước, rồi apply toàn bộ | Đơn giản, vẫn "không thao tác tay" | Dùng targeting — Terraform khuyến cáo chỉ dùng ngoại lệ; phải giải thích được |
| Tách 2 root module | `app-core` (plan, app) và `app-db-firewall` đọc output của core | Sạch về mô hình | Thêm một state, thêm độ phức tạp |
| IP ra cố định (NAT Gateway + VNet integration) | IP biết trước | Chuẩn production | **Tốn thêm tiền hằng giờ**, vượt scope |

Gợi ý cho dự án: **apply 2 pha trong Makefile** — nhưng bạn phải trả lời được câu "vì sao cần 2 pha" ở GATE.

Dùng `for_each` trên **tập** IP (khoá = chính IP), đặt tên rule từ IP (thay dấu chấm).

## 6. Outputs
URL app · FQDN MySQL · tên DB · client ID identity · tên RG.

## 7. Chạy
1. `fmt` → `validate` → `plan` → đọc kỹ: bao nhiêu resource tạo, có gì bất ngờ?
2. Apply (theo cách ở mục 5). Ghi thời gian mỗi pha — MySQL thường mất lâu nhất.
3. Kiểm tra Portal: URL placeholder 200 · slot có cùng identity · MySQL firewall có đúng số rule = số possible IPs · **không** có rule "allow Azure services" · **không** có IP máy bạn.
4. `plan` lần nữa → **No changes** (nếu có thay đổi lặp lại → tìm thuộc tính drift, ví dụ zone).
5. Mọi thứ qua PR: nhánh `feat/tf-compute-db` → CI (fmt/validate) xanh → merge.
6. **Destroy cuối buổi** → Portal: `rg-vsf-dev` biến mất, `rg-vsf-bootstrap` còn nguyên.

## Bẫy
- Mật khẩu có ký tự như `@` `:` `/` `?` → một số driver hiểu nhầm connection string.
- Quên gắn identity cho slot → D11 slot staging pull image lỗi.
- Tên app + slot quá dài → vượt giới hạn hostname.
- Plan mãi báo đổi zone MySQL → cần bỏ qua thay đổi thuộc tính zone.
- MySQL tạo xong nhưng destroy lại lâu (5–10 phút) — đừng tắt terminal giữa chừng (lock treo).

## Tự kiểm tra
1. Vì sao `for_each` trên outbound IPs lỗi ở lần apply đầu?
2. `for_each` hơn `count` ở đây thế nào?
3. `sensitive` có mã hoá mật khẩu trong state không?

## Xong khi
- [ ] apply từ zero thành công, plan lần 2 "No changes" · [ ] firewall rule = possible outbound IPs · [ ] Decision xử lý for_each · [ ] PR merged · [ ] destroy xong

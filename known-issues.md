# Known issues

Ba mục theo yêu cầu đề bài: **cái gì chưa xong** · **cái gì biết là sai** · **làm lại thì làm khác chỗ nào**.

## Chưa xong

| # | Việc | Chặn bởi | Dự kiến |
|---|---|---|---|
| 1 | Toàn bộ hạ tầng bằng Terraform (M8) | — | D7–D10 |
| 2 | ACR + Managed Identity + Key Vault (M1, M4, M5) | D10 | D11–D12 |
| 3 | CD pipeline và bằng chứng zero-downtime (M2, M10) | D13, D14 | D16–D18 |
| 4 | Monitoring, alert, runbook (M11) | D16 | D21–D22 |
| 5 | Câu hỏi Q1, Q3, Q4, Q5, Q8 chưa có trả lời từ mentor | mentor | xem plan |

## Biết là sai / chấp nhận tạm

| # | Vấn đề | Vì sao chấp nhận | Hệ quả nếu bỏ qua |
|---|---|---|---|
| 1 | **Mật khẩu MySQL của D3 đã lộ ra stdout** (`az mysql flexible-server create` in `password` và `connectionString`), không xoay vòng | server bị xoá trong ngày, dữ liệu là dữ liệu thử | Ở môi trường thật phải đổi mật khẩu ngay. Từ D9 mật khẩu do `random_password` sinh và nằm trong Key Vault |
| 2 | Ảnh trong `evidence/d02`, `d03` có **email cá nhân** và **IP nhà** ở góc màn hình | repo đang private | Nếu chuyển public phải che trước |
| 3 | Hook `pre-commit` nằm trong `.git/hooks/` nên **không theo repo** | giới hạn của git | Người clone mới phải tự cài; README ở D24 phải ghi rõ; CI là lớp chặn thật |
| 4 | Ảnh chụp của **D1 đã mất** (bộ nhớ đệm phiên chat bị xoá) | không khôi phục được | Nội dung đã chuyển thành chữ trong `notes/d1.md`; từ D2 ảnh lưu thẳng vào repo |
| 5 | `evidence/` nặng ~5.6 MB toàn ảnh PNG | chưa ảnh hưởng | Nếu vượt ~50 MB nên cân nhắc nén hoặc Git LFS |
| 6 | Hạ tầng nằm **2 vùng khác nhau**: App Service/ACR/Key Vault ở Central India, MySQL ở Southeast Asia (`var.location` ≠ `var.db_location`) | Subscription bị Azure throttle riêng cho tạo App Service Plan ở Southeast Asia (7 lần thử, 26 tiếng, không tự hết — `notes/d9.md`), và không có quyền tạo MySQL Flexible ở Central India (`ProvisionNotSupportedForRegion`). Không xin được subscription khác | Thêm latency mỗi query DB (2 vùng khác châu lục con — chấp nhận được cho môi trường học/dev, không có SLA thật). Nếu môi trường thật, phải chọn 1 vùng hỗ trợ đủ cả 2 dịch vụ cho đúng subscription trước khi build |
| 7 | **D10: lệnh `terraform` dài bị đứt kết nối giữa chừng** — `HTTP response was nil; connection may have been reset` (ghi state, gọi ARM), `unexpected EOF` (đọc state). 4 lần trong ngày 2026-09-21, trên `make up` và `make down`. Máy dùng Wi-Fi, Cloudflare WARP bật lúc lỗi (nghi, chưa chứng minh); kết nối tới `management.azure.com` đo được 1 lỗi/40 lần gọi | Không phải lỗi code Terraform: lock tự nhả, `plan` sau lỗi ra No changes, state nhất quán. Log lỗi giữ nguyên trong `evidence/raw/` | Không có cặp log `make up`/`make down` chạy trọn vẹn thì GATE D10 chưa có bằng chứng "sạch". Một lần lỗi giữa `make up` còn có thể để state dở dang (thiếu `possible_outbound_ip_address_list` của Web App) làm `make down` báo `Invalid for_each` — gỡ bằng `destroy -target`, xem `notes/d10.md` |
| 8 | **D10: một lần `make up` lỗi `error asking for approval: EOF`** do người chạy lệnh (Claude) truyền `yes` bằng `printf 'yes\nyes\n'`; pha 1 đọc hết luồng | Lỗi cách chạy, không liên quan hạ tầng. Khi chạy tay trong terminal không xảy ra | Log lần đó không dùng làm bằng chứng sạch; đã ghi thành case #9 trong `ai-failure-log.md` (case #10 là lần `make down` bị `Invalid for_each`) |

## Làm lại thì làm khác chỗ nào

| # | Đã làm | Lần sau sẽ làm |
|---|---|---|
| 1 | Chọn base `distroless/cc` trước rồi mới đổi sang `scratch` + musl | Bắt đầu thẳng bằng musl tĩnh: 5.2 MB và **0 CVE** ngay từ đầu, khỏi mất 1 vòng build 9 phút |
| 2 | Dùng `gitleaks/gitleaks-action@v2` trong CI | Chạy thẳng binary đã ghim version — ít quyền hơn, không phụ thuộc hành vi của action |
| 3 | D2 làm mọi thứ trên Portal rồi D3 lặp lại bằng CLI | Giữ nguyên thứ tự này: đúng là **phải làm tay trước** mới thấy Portal giấu gì (`httpsOnly`, hậu tố hostname, `scmUseMain`) |
| 4 | Biến shell (`$RG`, `$MYSQL_PW`) mất 3 lần trong buổi D3 | Ghi vào file `.env` và `source`, hoặc bỏ hẳn shell script và dùng Terraform sớm hơn |
| 5 | Ước tính chi phí bằng tay trước, đối chiếu sau | Giữ: sai số dưới 15%, đủ tin cho cost report |
| 6 | Gặp lỗi 429 "throttled" khi tạo App Service Plan ở D9 → thử lại nhiều lần qua nhiều giờ trước khi nghĩ tới đổi vùng | Ngay khi gặp lỗi hạ tầng dạng "throttle"/"quota" khó hiểu và lặp lại y hệt, thử **1 lệnh `az` đơn lẻ ở vùng khác** (không qua Terraform/retry) để tách bạch "lỗi do subscription nói chung" hay "lỗi đặc thù 1 vùng" — chỉ mất vài giây, tiết kiệm hơn hẳn so với chờ hàng giờ đoán mò |
| 7 | Ở D10 chạy `make up` / `make down` dài (10–40 phút) trên Wi-Fi có VPN/tunnel bật, đứt giữa chừng 4 lần rồi mới nghi tới đường mạng | **Trước** mỗi lệnh Terraform dài: tắt VPN/WARP, ưu tiên cáp mạng, đo nhanh 20–30 lần `curl` tới `management.azure.com` và blob storage. Khi lệnh đứt: kiểm lock → so state với Azure → chạy lại, không chạy tiếp `destroy` cho tới khi đã thấy `plan` |

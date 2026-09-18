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
| 6 | D9 `make up` pha 1 (tạo `azurerm_service_plan.app`) bị Azure trả **429 Too Many Requests**, code `51025`: *"App Service Plan Create operation is throttled for subscription ... Please contact support if issue persists."* — **5 lần thử** trong hơn 1.5 tiếng (90s, ~40 phút, ~26 phút, ~50 phút giữa các lần), tất cả cùng lỗi không đổi | Azure throttle cấp subscription, kéo dài bất thường. `az monitor activity-log` cho thấy mỗi lần `terraform apply` tự retry nội bộ ~30 lần trong 6 phút — nhiều lần thử cộng lại có thể đã dội hàng trăm request vào đúng endpoint | **Không còn coi là throttle ngắn hạn.** Đã dừng tự động thử lại. Cần: (a) liên hệ Azure support thật (thông điệp lỗi gợi ý đúng việc này), hoặc (b) hỏi mentor về Q5 sớm hơn dự kiến (đổi sang subscription khác). State hiện tại (`rg-vsf-dev`) vẫn sạch — chỉ resource group + identity + random_string, chưa có gì tốn tiền bị treo dở, không cần dọn gì trước khi thử tiếp |

## Biết là sai / chấp nhận tạm

| # | Vấn đề | Vì sao chấp nhận | Hệ quả nếu bỏ qua |
|---|---|---|---|
| 1 | **Mật khẩu MySQL của D3 đã lộ ra stdout** (`az mysql flexible-server create` in `password` và `connectionString`), không xoay vòng | server bị xoá trong ngày, dữ liệu là dữ liệu thử | Ở môi trường thật phải đổi mật khẩu ngay. Từ D9 mật khẩu do `random_password` sinh và nằm trong Key Vault |
| 2 | Ảnh trong `evidence/d02`, `d03` có **email cá nhân** và **IP nhà** ở góc màn hình | repo đang private | Nếu chuyển public phải che trước |
| 3 | Hook `pre-commit` nằm trong `.git/hooks/` nên **không theo repo** | giới hạn của git | Người clone mới phải tự cài; README ở D24 phải ghi rõ; CI là lớp chặn thật |
| 4 | Ảnh chụp của **D1 đã mất** (bộ nhớ đệm phiên chat bị xoá) | không khôi phục được | Nội dung đã chuyển thành chữ trong `notes/d1.md`; từ D2 ảnh lưu thẳng vào repo |
| 5 | `evidence/` nặng ~5.6 MB toàn ảnh PNG | chưa ảnh hưởng | Nếu vượt ~50 MB nên cân nhắc nén hoặc Git LFS |

## Làm lại thì làm khác chỗ nào

| # | Đã làm | Lần sau sẽ làm |
|---|---|---|
| 1 | Chọn base `distroless/cc` trước rồi mới đổi sang `scratch` + musl | Bắt đầu thẳng bằng musl tĩnh: 5.2 MB và **0 CVE** ngay từ đầu, khỏi mất 1 vòng build 9 phút |
| 2 | Dùng `gitleaks/gitleaks-action@v2` trong CI | Chạy thẳng binary đã ghim version — ít quyền hơn, không phụ thuộc hành vi của action |
| 3 | D2 làm mọi thứ trên Portal rồi D3 lặp lại bằng CLI | Giữ nguyên thứ tự này: đúng là **phải làm tay trước** mới thấy Portal giấu gì (`httpsOnly`, hậu tố hostname, `scmUseMain`) |
| 4 | Biến shell (`$RG`, `$MYSQL_PW`) mất 3 lần trong buổi D3 | Ghi vào file `.env` và `source`, hoặc bỏ hẳn shell script và dùng Terraform sớm hơn |
| 5 | Ước tính chi phí bằng tay trước, đối chiếu sau | Giữ: sai số dưới 15%, đủ tin cho cost report |

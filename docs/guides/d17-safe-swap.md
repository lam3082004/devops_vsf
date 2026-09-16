# D17 — Swap an toàn

**Cần:** D16 · **Chi phí:** có · **Nhật ký:** `notes/d17.md`

## Mục tiêu
Swap chỉ xảy ra khi bản mới **đã chạy, đã nóng, đúng SHA, DB kết nối được** — và tự quay lại nếu kiểm tra sau swap thất bại.

## 1. Cơ chế swap cần hiểu
1. Nền tảng áp **cấu hình production** (trừ setting sticky) lên instance staging → restart staging.
2. Gọi **warm-up** tới staging cho tới khi trả mã hợp lệ (hoặc hết thời gian).
3. Đổi định tuyến: staging ↔ production. Instance cũ vẫn phục vụ tới lúc đổi.

## 2. Cấu hình (Terraform, cả app và slot)

| Cấu hình | Giá trị | Vì sao |
|---|---|---|
| Health check path | `/health` + thời gian loại instance lỗi hợp lý | nền tảng loại instance hỏng |
| Swap warm-up path | `/health` | swap chỉ đổi khi app thật sẵn sàng |
| Swap warm-up statuses | `200` | 503 (DB lỗi) không được coi là sẵn sàng |
| Thời gian khởi động container tối đa | vừa đủ (app nhỏ khởi động vài giây) | |
| Always on | bật | |

**Sticky settings (slot setting) — ghi Decision:**
| Setting | Sticky? | Lý do |
|---|---|---|
| Biến DB, KV reference | Không (giống nhau 2 slot) | |
| Tên môi trường slot (nếu có biến `SLOT_NAME`) | Có | nhận biết slot |
| SHA | **không phải app setting** — nhúng trong image | tránh sai log M2 |

## 3. Bổ sung CD (thay bước 8 của D16)

| # | Bước | Chi tiết |
|---|---|---|
| 8a | Lấy IP công khai của runner | |
| 8b | Thêm luật access restriction **tạm** cho IP runner vào slot staging (và production cho bước 10) | tên luật có run ID |
| 8c | Poll staging `/version` + `/health` mỗi 5s, tối đa ~5 phút | thành công khi SHA = commit **và** health 200 |
| 8d | Hết thời gian → **dừng, không swap**, job đỏ | |
| 9 | Swap | |
| 10 | Kiểm tra production `/version` = SHA, `/health` 200 (vài lần) | |
| 10b | Thất bại → **swap ngược** (production ↔ staging) → job đỏ | rollback tự động |
| 11 | **Luôn** xoá luật tạm (bước chạy kể cả khi job lỗi/huỷ) | tránh thủng whitelist |

## 4. Thử các tình huống

| Tình huống | Cách tạo | Mong đợi |
|---|---|---|
| Bình thường | merge thay đổi nhỏ | swap, production = SHA mới |
| Bản mới không khởi động | PR làm app thoát khi start (ví dụ đòi biến không tồn tại) | 8d dừng, **production không đổi** |
| Bản mới chạy nhưng `/health` 503 | PR làm health luôn 503 | không swap |
| Luật tạm | xem Portal khi job xong | không còn luật tên run ID |

Mỗi tình huống lỗi làm trên PR riêng rồi **revert** ngay qua PR. Ghi link run vào note.

## Bẫy
- Luật tạm thêm xong test ngay vẫn 403 vài giây — poll có retry.
- Bước dọn không chạy khi job bị huỷ → luật mồ côi. Kiểm tra định kỳ; D22 runbook có mục dọn.
- Warm-up path sai → swap coi 404 là "đã phản hồi" tuỳ cấu hình statuses.
- Swap ngược khi staging đã bị deploy đè → quay về bản sai. Chỉ swap ngược ngay trong cùng run.
- Migration DB không tương thích ngược → swap ngược vẫn lỗi (D4 expand/contract).

## Tự kiểm tra
1. Vì sao warm-up statuses nên chỉ là 200?
2. Sau swap, bản cũ nằm ở đâu? Giữ nó bao lâu?
3. Tại sao bước xoá luật tạm phải chạy vô điều kiện?

## Xong khi
- [ ] health check + warm-up cấu hình bằng Terraform · [ ] CD chờ đúng SHA trước swap · [ ] rollback tự động · [ ] 3 tình huống lỗi có run link · [ ] không còn luật tạm

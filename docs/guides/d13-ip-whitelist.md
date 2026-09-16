# D13 — IP whitelist

**Cần:** D12 · **Chi phí:** có · **Bằng chứng:** `evidence/M6.md`

## Mục tiêu (M6)
Chỉ IP cho phép truy cập được app. `curl` từ IP cho phép → 200; từ IP khác (hotspot điện thoại hoặc VM region khác) → 403.

## 1. Biến
- `allowed_ips`: danh sách CIDR `/32` (IP nhà/văn phòng bạn, IP mentor nếu cần demo). **Giá trị cá nhân → file biến không commit** hoặc GitHub Variable cho CI; trong repo chỉ có file ví dụ.
- Lưu ý IP nhà thay đổi → ghi quy trình cập nhật vào README.

## 2. Terraform: luật truy cập

Áp cho **cả 4 bề mặt**:

| Bề mặt | Cấu hình |
|---|---|
| Web App (site chính) | mỗi IP một luật Allow (ưu tiên 100, 110…) · **hành động mặc định Deny** |
| Web App (site SCM/Kudu) | dùng chung luật site chính **hoặc** luật riêng chặt hơn — ghi Decision |
| Slot staging (site chính) | giống production |
| Slot staging (SCM) | giống trên |

Đặt tên luật có nghĩa (`allow-home`, `allow-mentor`).

## 3. Kiểm chứng
1. Tra IP công khai hiện tại của máy (một dịch vụ trả IP dạng text).
2. Từ máy: curl URL production + URL staging + URL SCM → 200 (SCM có thể 401/redirect đăng nhập — miễn không phải 403).
3. Kết nối laptop vào **hotspot 4G của điện thoại** → tra IP (khác IP nhà) → curl 3 URL → **403**.
4. Lưu output dạng:

   ```
   2026-09-22T10:01:02+07:00  source_ip=203.0.113.10  GET https://…/version  → 200
   2026-09-22T10:03:40+07:00  source_ip=198.51.100.7  GET https://…/version  → 403
   ```

5. Portal: Networking → Access restrictions → chụp danh sách luật (che IP nếu repo public).

## 4. Quyết định cho CI/CD (ghi Decision — dùng ở D17)
Runner GitHub-hosted **không có IP cố định** → bước kiểm tra staging bằng HTTP sẽ nhận 403.

| Cách | Mô tả | Đánh giá |
|---|---|---|
| **Mở tạm IP runner** | CD lấy IP runner → thêm luật tạm cho staging (và prod khi verify) → kiểm tra → **luôn xoá luật** trong bước dọn chạy kể cả khi job lỗi | Khuyên dùng; cần quyền sửa access restriction |
| Chỉ dựa vào warm-up của swap | Không gọi HTTP từ runner | Yếu hơn: không tự kiểm tra SHA |
| Self-hosted runner trong mạng đã whitelist | | Thêm máy phải vận hành |
| Mở dải IP GitHub | | Hàng nghìn dải, gần như mở toang — không đạt M6 |

## Bẫy
- **IPv6:** máy/mạng ưu tiên IPv6 → request đi bằng IPv6 → không khớp luật IPv4 → chính bạn nhận 403. Kiểm tra IP nguồn thực tế; ép IPv4 khi test hoặc thêm luật IPv6.
- Quên slot hoặc SCM → staging/Kudu vẫn mở với Internet.
- Luật mới có hiệu lực sau vài giây — test ngay có thể thấy kết quả cũ.
- Hotspot điện thoại đôi khi dùng chung IP với Wi-Fi nếu điện thoại đang bắt Wi-Fi nhà — tắt Wi-Fi điện thoại.
- IP nhà đổi → sáng hôm sau `make up` xong tự bị 403.

## Tự kiểm tra
1. Vì sao deploy từ runner vẫn được (qua ARM) mà gọi HTTP lại 403?
2. Access restriction chặn tầng nào — trước hay sau khi request tới container?
3. IP whitelist có thay được xác thực người dùng không?

## Xong khi
- [ ] 4 bề mặt có luật · [ ] log 200 và 403 kèm IP nguồn · [ ] `evidence/M6.md` · [ ] Decision cho runner

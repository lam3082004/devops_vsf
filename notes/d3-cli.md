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

- [ ] 0. Kiểm tra `az version`, tài khoản, subscription mặc định
- [ ] 1. Tạo RG `rg-d3-cli` (Southeast Asia)
- [ ] 2. Tạo MySQL Flexible B1ms 20 GiB, public access, firewall = IP máy mình
- [ ] 3. Tạo App Service Plan Linux P0V3
- [ ] 4. Tạo Web App container image mẫu → URL trả 200
- [ ] 5. In outbound IPs (current + possible) ở dạng bảng
- [ ] 6. Vòng lặp shell: thêm firewall rule MySQL cho **từng** possible IP
- [ ] 7. Access restriction: allow IP mình, mặc định Deny (nhớ cả SCM) → thử 403
- [ ] 8. Tạo slot `staging`, gán image, swap
- [ ] 9. Scale out 2 → về 1
- [ ] 10. Thí nghiệm idempotency: chạy lại lệnh tạo lần 2
- [ ] 11. Xoá RG, kiểm tra trống

## Lệnh đã dùng

Với mỗi bước ghi: lệnh · từng tham số nghĩa là gì · tham số nào Portal đã tự điền hộ ở D2.

### 0. Kiểm tra môi trường
```bash
```

### 1. Resource group
```bash
```

## Thí nghiệm idempotency

| Lệnh chạy lần 2 | Kết quả | Giải thích |
|---|---|---|

## So với D2: Portal đã giấu gì

| Tham số | Portal D2 | CLI D3 bắt khai báo |
|---|---|---|

## Lỗi gặp và cách xử lý

| Lỗi (nguyên văn rút gọn) | Nguyên nhân | Cách sửa |
|---|---|---|

## Tự kiểm tra
1. Portal, CLI, Terraform giống nhau ở điểm nào?
2. Vì sao chạy lại script CLI thường lỗi, còn `terraform apply` lần hai là "No changes"?
3. Tham số nào của MySQL nếu để mặc định sẽ tốn tiền hơn cần thiết?

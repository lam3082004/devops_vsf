# D12 — Key Vault reference · MySQL · app gãy khi mất quyền

**Cần:** D11 (hoặc làm xen kẽ) · **Chi phí:** có · **Bằng chứng:** `evidence/M3.md`, `evidence/M4.md`, `evidence/M5.md`

> **Kế hoạch chi tiết của phiên này: `notes/d12-prep.md`** (11 bước, 4 decision, 2 việc chặn phải xong trước khi tiêu tiền).
> Tình trạng 2026-09-22: **mục 1–2 đã xong từ D11** (commit `c710815`: app settings DB + `DB_PASSWORD` Key Vault reference không version + `key_vault_reference_identity_id`, đã đo **Resolved** cả 2 slot) và **mục 3 (firewall) đã đúng từ D8**. Còn lại thật sự: M3 đo lại có ảnh Log stream, M4 rà app settings, M5 chứng minh ngược — cộng ô chứng minh ngược AcrPull còn nợ của M1.

## Mục tiêu
- **M3:** `/items` đọc ghi MySQL; firewall MySQL **chỉ** mở cho outbound IPs của App Service.
- **M4:** Managed Identity đọc Key Vault + pull ACR; **không secret plaintext** trong app settings.
- **M5:** app config dùng `@Microsoft.KeyVault(...)`; **xoá quyền MI khỏi KV → app phải gãy**.

## 1. App settings (Terraform, cho cả app và slot)

| Biến | Giá trị | Loại |
|---|---|---|
| `DB_HOST` | output FQDN MySQL | cấu hình thường |
| `DB_NAME` | `appdb` | thường |
| `DB_USER` | `vsfadmin` | thường |
| `DB_TLS` | `true` | thường |
| `DB_PASSWORD` | tham chiếu Key Vault tới secret `mysql-admin-password` — dùng URI **không kèm version** để tự nhận bản mới khi xoay vòng | **Key Vault reference** |

Và thuộc tính **identity dùng cho Key Vault reference** = id của user-assigned MI (nếu không, nền tảng dùng system-assigned → không resolve được).

## 2. Kiểm chứng Key Vault reference
1. Apply → Portal: Web App → **Settings → Environment variables** → dòng `DB_PASSWORD` có nhãn **Key vault Reference** và trạng thái **resolved** (dấu xanh). Chụp.
2. Làm tương tự cho slot staging.
3. Rà toàn bộ app settings: không còn giá trị nào là mật khẩu, key, connection string có mật khẩu. Chụp → `M4.md`.

## 3. Firewall MySQL đúng M3
- Chỉ các rule sinh từ possible outbound IPs.
- **Không** có rule IP máy bạn (nếu cần debug: thêm tạm qua biến, xoá sau, ghi lại).
- **Không** bật "allow Azure services".
- Portal MySQL → Networking → chụp danh sách rule. So số lượng với Web App → Properties.

## 4. `/items` trên Azure (M3)
Từ máy bạn (whitelist chưa bật ở bài này, hoặc từ IP đã allow nếu D13 xong trước):
1. `GET /health` → 200 `db: ok`
2. `POST /items` với name có timestamp → 201
3. `GET /items` → thấy bản ghi
4. Lưu output kèm thời gian → `M3.md`
5. Log Analytics chưa có thì dùng **Log stream** chụp log JSON của 2 request.

## 5. Chứng minh ngược M5 — quy trình ghi log

| Bước | Hành động | Kết quả mong đợi | Ghi thời gian |
|---|---|---|---|
| 0 | `/items` + `/health` | 200 | |
| 1 | **Gỡ role Key Vault Secrets User** của identity app khỏi vault (qua PR đặt biến tắt role, hoặc Portal — nếu Portal thì ghi rõ là drift có chủ đích) | assignment biến mất | |
| 2 | Chờ vài phút cho quyền hết hiệu lực | | |
| 3 | **Làm mới tham chiếu**: restart app (hoặc gọi thao tác refresh Key Vault references) — vì giá trị đang được cache | | |
| 4 | Environment variables | `DB_PASSWORD` báo lỗi tham chiếu (đỏ) | |
| 5 | Log stream | app log `fatal` về `DB_PASSWORD` rồi thoát; container restart liên tục | |
| 6 | curl `/health` | **không phải 200** (503/502 hoặc lỗi kết nối) | |
| 7 | Trả role (apply lại, xoá drift) → chờ → restart | tham chiếu xanh lại | |
| 8 | `/health`, `/items` | 200 | |

`M5.md`: bảng trên + screenshot bước 4, 5, 6, 8 + giải thích **vì sao gỡ quyền không làm app gãy ngay** (cache).

## Bẫy
- Gỡ quyền nhưng không restart → app vẫn chạy → tưởng M5 thất bại.
- Chỉ gỡ ở vault nhưng identity còn role kế thừa từ RG/subscription → vẫn đọc được. Kiểm tra IAM của vault → **Check access** cho identity.
- Tham chiếu có version → xoay vòng secret không có hiệu lực.
- Mật khẩu có ký tự đặc biệt bị app parse sai → lỗi xác thực MySQL dù tham chiếu xanh.
- TLS: image tối giản thiếu chứng chỉ CA → lỗi x509. Kiểm tra image có bộ CA.
- Sau M5 quên apply lại → plan ngày mai thấy drift.

## Tự kiểm tra
1. Nền tảng dùng danh tính nào để resolve tham chiếu, cấu hình ở đâu?
2. Vì sao app nên fail-fast khi thấy chuỗi `@Microsoft.KeyVault(`?
3. Firewall MySQL theo outbound IP có chặn được app khác cùng scale unit Azure không? (hạn chế của cách này — gợi ý: S3 Private Endpoint)

## Xong khi
- [ ] tham chiếu xanh cả 2 slot · [ ] `/items` đọc ghi · [ ] firewall đúng · [ ] M5 gãy → hồi phục có log · [ ] `evidence/M3.md` `evidence/M4.md` `evidence/M5.md` · [ ] drift đã xoá

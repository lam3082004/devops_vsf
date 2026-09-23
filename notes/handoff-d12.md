# Bàn giao phiên 2026-09-22 — D12 dở dang, D13 sẵn sàng

Đọc file này trước khi mở phiên mới. Chi tiết từng bài: `notes/d12-prep.md`, `notes/d12.md`, `notes/d13-prep.md`.

## Trạng thái: D12 XONG (2026-09-23 08:42)

M3, M4, M5 đều đạt, ô chứng minh ngược của M1 đã điền, `terraform plan` cuối cùng ra
**No changes**. Môi trường đã destroy (xem mục cuối nếu lần destroy thứ hai có vấn đề).

Bằng chứng: `evidence/M1.md`, `M3.md`, `M4.md`, `M5.md` — số liệu thật, có giờ.
Log thô: `evidence/raw/d12-*`. Nhật ký + 5 sai sót của phiên: `notes/d12.md`.

### Còn thiếu của D12 — chỉ là ảnh, làm ở phiên nào có môi trường bật

1. Environment variables **production** và **slot staging**: `DB_PASSWORD` nhãn
   *Key vault Reference* + **Resolved**. (Ảnh D11 `07`/`08` dùng tạm được, cấu hình không đổi.)
2. **Log stream** lúc gọi `/health` và `POST /items` — bằng chứng #4 của M3.
3. **MySQL → Networking**: danh sách firewall rule.
4. Gọi API `configreferences` cho **slot staging** — M4 ô5, ô duy nhất còn `CHƯA ĐO`.

### Ba kết quả đáng nhớ nhất

- **M5:** `"status": "AccessToKeyVaultDenied"` trong khi `identityType` **vẫn** `UserAssigned`
  → nền tảng dùng đúng danh tính, chỉ mất quyền. Phân biệt được với lỗi cấu hình sai
  `key_vault_reference_identity_id` (khi đó ra `SystemAssigned`) — hai lỗi triệu chứng giống hệt.
  Container `exit code 1 sau 0.2s`: app kiểm cấu hình rồi thoát, không thử nối MySQL.
- **M1 ngược:** lần đầu **thất bại** — gỡ `AcrPull` + restart mà app vẫn 200, vì image đã cache
  trên worker. Phải đẩy tag mới để ép pull mới ra `ACRTokenRetrievalFailure … Unauthorized`.
  Cùng bài học với cache Key Vault: **thu hồi quyền không tự làm gãy thứ đang chạy**.
- **M3:** **31** firewall rule = **31** possible outbound IP. D8/D9 đo được 20 — con số này
  đổi theo scale unit, nên bằng chứng phải so hai số với nhau, đừng ghim số cứng.

## Đã vào `main`

| PR | Nội dung | Commit |
|---|---|---|
| #18 | D11: pull ACR bằng MI + app settings DB/Key Vault reference | `eeddb4e` |
| #19 | Kế hoạch D12 | `2fde140` |
| #20 | `grant_app_keyvault_access` + `grant_app_acr_pull` | `0930f40` |
| #21 | Khung bằng chứng M3/M4/M5 | `61fd7c7` |
| #26 | `scripts/d12-verify.sh` | `7db4994` |

**Chưa merge:** PR #27, nhánh `feat/d12-evidence` — bằng chứng D12 đầy đủ + kế hoạch D13 +
`known-issues.md` #9. CI job `terraform plan` từng đỏ vì môi trường dựng dở; môi trường đã
destroy nên re-run là xanh.

## D13 — sẵn sàng bắt đầu

Kế hoạch đầy đủ: `notes/d13-prep.md` (4 decision, 8 bước, bảng bẫy, gợi ý trả lời 3 câu tự
kiểm tra). Hai điều đã chốt trước khi viết code:

- **Hạ tầng chưa có luật truy cập nào** (`grep ip_restriction/allowed_ips infra/` trống) →
  viết mới cho **4 bề mặt**: site chính + SCM, nhân 2 cho slot staging.
- **Cách test của guide không dùng được.** Guide bảo đổi sang hotspot điện thoại để có IP khác,
  nhưng máy làm việc vốn đã chạy bằng chính hotspot đó → chung một IP công khai → curl vẫn ra
  200 và dễ tưởng luật hỏng. Lấy 403 từ **GitHub Actions** (miễn phí, lặp lại được, đồng thời
  là bằng chứng cho quyết định CD ở D17), Azure Cloud Shell làm lần đo thứ hai.

Tên thuộc tính azurerm đã kiểm bằng `terraform providers schema`, không đoán:
`ip_restriction_default_action`, `scm_use_main_ip_restriction`, block `ip_restriction`
(`name`/`ip_address`/`action`/`priority`/`description`).

D13 cần môi trường có **slot staging** → phụ thuộc pha 2 của `make up`, không phụ thuộc
M3/M4/M5 đã đo xong. Làm xen kẽ được.

## Trạng thái git

- `main` = `7db4994`.
- Nhánh `feat/d12-evidence`, PR #27 mở — chờ re-run CI rồi merge.
- Worktree làm việc: `.claude/worktrees/d12` (sạch, có `app/Dockerfile` nên `docker build app/` chạy được).
- Checkout chính đang ở nhánh khác (`feat/be-integration-tests`) với refactor OpsBoard chưa
  commit — **đừng `git add -A` ở đó**.
- Worktree cũ `.claude/worktrees/docs-d10-close-d11-plan` còn giữ nhánh `feat/d11-acr-mi-pull`
  đã merge, xoá được.

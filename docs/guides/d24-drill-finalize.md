# D24 — Incident drill · hoàn thiện tài liệu

**Cần:** D22 · **Chi phí:** có · **Deliverable:** timeline drill, `architecture.md`, `README.md`, `known-issues.md`, `ai-failure-log.md`, `evidence/` đầy đủ

## Phần A — Incident drill

### 1. Kịch bản (chọn 2)

| # | Gây sự cố | Alert/triệu chứng mong đợi | Xử lý đúng |
|---|---|---|---|
| A | Merge PR làm `/items` trả 500 | alert 5xx | runbook → swap ngược |
| B | Gỡ role Key Vault của MI + restart | app restart liên tục, `/health` lỗi | kiểm tra KV reference → apply lại quyền |
| C | Xoá 1 firewall rule MySQL (hoặc đổi tier làm IP ra đổi) | `/health` 503, lỗi kết nối DB | so outbound IPs với firewall → apply |
| D | Test tải kéo dài | alert CPU, 2 instance | xác nhận autoscale, dừng tải |

**Tốt nhất:** nhờ bạn intern kia **gây sự cố mà không báo trước kịch bản nào** (cần quyền trên subscription của bạn — nếu không, bạn tự gây nhưng nhờ bạn kia bấm giờ và quan sát).

### 2. Timeline (điền trong lúc làm)

| Thời điểm | Sự kiện | Ai/cái gì phát hiện | Hành động |
|---|---|---|---|
| T0 | gây sự cố | | |
| T+? | alert Fired / nhận email | | |
| T+? | xác nhận nguyên nhân (truy vấn nào) | | |
| T+? | hành động xử lý | | |
| T+? | phục hồi (`/health` 200, failure rate 0) | | |
| T+? | alert Resolved | | |

Tính: thời gian phát hiện · thời gian phục hồi (MTTR của lần diễn tập).

### 3. Postmortem ngắn (không đổ lỗi) → `docs/drills/<ngày>.md`
- Tóm tắt · tác động · timeline · nguyên nhân gốc
- Điều làm tốt · điều chưa tốt (runbook thiếu bước nào? alert chậm?)
- Action items → sửa runbook qua PR / thêm `known-issues.md`

## Phần B — Dựng lại lần cuối theo README

1. Clone **mới** repo vào thư mục khác.
2. Làm **đúng từng bước** trong `README.md`, không dùng trí nhớ. Bước nào thiếu/sai → sửa README.
3. `make down` → `make up` → CD deploy → kiểm tra `/version`, `/items`, dashboard, alert.
4. Log → cập nhật `evidence/M8.md` (lần cuối).

## Phần C — Hoàn thiện tài liệu

### `README.md` — người thứ ba dựng lại được
- Tổng quan 3 dòng + link `architecture.md`
- **Prerequisites:** tài khoản/quyền Azure cần có (Owner hoặc tương đương, provider đã register), công cụ + phiên bản (Terraform, Azure CLI, Docker, gitleaks, Trivy)
- **Bootstrap một lần:** state storage, danh tính CI/CD, GitHub Variables/Environment
- **Biến cần set:** bảng tên · ý nghĩa · ví dụ · lấy ở đâu (không có giá trị thật)
- **Hằng ngày:** `make up`, `make down`, `make check-empty`
- **Deploy:** quy trình PR → CI → merge → CD
- **Teardown hoàn toàn:** down app · xoá bootstrap (cảnh báo: mất state) · purge Key Vault · xoá federated credential
- **Troubleshooting:** trỏ tới `known-issues.md`, `runbook.md`

### `architecture.md` — 2 sơ đồ mermaid tách biệt
1. **Luồng traffic:** người dùng (IP whitelist) → App Service (access restriction) → slot production/staging → MySQL (firewall theo outbound IPs); GitHub Actions → ACR → slot staging → swap.
2. **Luồng auth:** GitHub OIDC → Entra → `id-gh-plan` / `id-gh-deploy` → quyền; App Service → user-assigned MI → token → ACR (AcrPull) / Key Vault (Secrets User); Terraform (bạn) → Key Vault (Secrets Officer), state storage (Blob Data Contributor); MySQL xác thực bằng mật khẩu lấy từ Key Vault.

Mỗi mũi tên ghi **giao thức/danh tính/role**. Kèm bảng "danh tính → role → scope".

### `known-issues.md`
Ba mục theo đề: **chưa xong** · **biết là sai** · **làm lại thì làm khác chỗ nào** (ví dụ: IP whitelist vs Private Endpoint, apply 2 pha, log mất mỗi ngày).

### `ai-failure-log.md`
Đủ **6–8 case**, mỗi case: yêu cầu · AI sinh gì · sai ở đâu (cụ thể: tên thuộc tính không tồn tại, quyền quá rộng, lệnh sai flag…) · phát hiện bằng gì (plan lỗi, CI đỏ, docs) · sửa thế nào · bài học.

### `evidence/` — soát cuối
| File | Có log/screenshot thật | Link tới run/PR | Ngày |
|---|---|---|---|
| M1 … M11 | | | |

## Xong khi
- [ ] 2 drill có timeline + postmortem · [ ] dựng lại từ clone mới theo README thành công · [ ] README, architecture (2 sơ đồ), known-issues, ai-failure-log (≥ 6), evidence M1–M11 đầy đủ · [ ] `make down`

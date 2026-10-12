# AKS · tương đương M3 — MySQL làm database

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M3 của đề bài là [`../M3.md`](../M3.md).

Ngày: 2026-10-12 · log thô: [`../raw/aks-p2-2026-10-12.log`](../raw/aks-p2-2026-10-12.log) (mục M3)

Tiêu chí của đề: *`/items` đọc ghi được; firewall MySQL chỉ mở cho outbound IP của nơi chạy app.*

| # | Bằng chứng | Kết quả thật |
|---|---|---|
| 1 | Ghi qua `fe` → `be` → MySQL | `POST http://<LB>/api/tickets` → **HTTP 201**, `{"id":1,"title":"AKS advanced: ghi thu tu P2",…}` |
| 2 | `be` ghi nhận request | log `{"event":"request","method":"POST","path":"/items","status":201,"duration_ms":296,…}` |
| 3 | Đọc lại | `GET /items?limit=1` (qua `kubectl proxy`) → **200**, trả đúng ticket `id 1` |
| 4 | `be /health` | `{"status":"ok","db":"ok"}` — readiness probe của pod dùng chính endpoint này |
| 5 | Firewall | rule **`aks-outbound`**: `start = end = 4.144.x.x` = IP outbound của cluster (`aks-verify`: *firewall MySQL aks-outbound = IP outbound của cluster*) |
| 6 | Kết nối TLS | `DB_TLS = "true"` trong ConfigMap `be-config`; MySQL Flexible từ chối kết nối không TLS |
| 7 | Dữ liệu tách khỏi bài chính | server có hai database `appdb` (App Service) và **`appdb_aks`** (AKS); `be` trên AKS chỉ có `DB_NAME = appdb_aks` |

## Khác App Service ở đâu

- App Service: ~20 "possible outbound IP" **dùng chung cả stamp** → 20 firewall rule, và phải apply nhiều pha vì
  IP là khoá của `for_each` (`infra/app/db.tf`). Hạn chế đã ghi ở cuối `../M3.md`: app của khách hàng khác cùng
  stamp cũng lọt qua firewall.
- AKS: `managed_outbound_ip_count = 1` → **một** IP của riêng cluster, một rule, apply một pha.

## Giới hạn

- `be` trên AKS đăng nhập MySQL bằng **cùng tài khoản admin** `vsfadmin` với bài chính (đọc cùng secret
  `mysql-admin-password`). Database tách, nhưng quyền thì không: pod `be` trên AKS về lý thuyết đọc được `appdb`.
  Tạo user riêng cần chạy SQL ngoài Terraform (hoặc Entra auth — S2, đã đóng vì thiếu quyền tenant). Ghi ở `known-issues.md`.
- Cluster (East Asia) và MySQL (Southeast Asia) khác region, như bài chính (Central India ↔ Southeast Asia).

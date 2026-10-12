# AKS · tương đương M4 + M5 — managed identity, Key Vault, chứng minh ngược

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng của đề bài là [`../M4.md`](../M4.md) và [`../M5.md`](../M5.md).

Ngày: 2026-10-12 · Key Vault `kv-vsf-jcip0s` (của bài chính, dùng lại)
Log thô: [`../raw/aks-p2-2026-10-12.log`](../raw/aks-p2-2026-10-12.log) (mục M4) · [`../raw/aks-m5-2026-10-12.log`](../raw/aks-m5-2026-10-12.log)

Tiêu chí của đề: *MI đọc Key Vault + pull ACR; không secret plaintext nào trong cấu hình app (M4). Xoá quyền MI
khỏi Key Vault → app phải gãy (M5).*

## Luồng secret

```
Pod be (ServiceAccount opsboard/be)
   │ 1. kubelet mount volume CSI → driver xin token cho CHÍNH service account của pod
   ▼
Entra ID: federated credential  subject = system:serviceaccount:opsboard:be
   │ 2. đổi lấy token của id-vsf-aks-be-jcip0s (không secret, không chứng chỉ)
   ▼
Key Vault: RBAC ở scope TỪNG SECRET — Key Vault Secrets User
   │ 3. trả giá trị → driver ghi vào volume + đồng bộ sang Secret `be-secrets`
   ▼
Container: env DB_PASSWORD ← secretKeyRef be-secrets/DB_PASSWORD
```

## M4 — bảng bằng chứng

| # | Bằng chứng | Kết quả thật |
|---|---|---|
| 1 | Role của `id-vsf-aks-be-jcip0s` | `Key Vault Secrets User` trên **2 secret**: `…/secrets/mysql-admin-password`, `…/secrets/aks-appinsights-connection-string` — không có role ở scope vault |
| 2 | Role của `id-vsf-aks-fe-jcip0s` | `Key Vault Secrets User` trên **1 secret**: `aks-appinsights-connection-string`. Không chạm được mật khẩu DB |
| 3 | Secret trong namespace | `be-secrets`, `fe-secrets` — cả hai có nhãn `secrets-store.csi.k8s.io/managed=true` (driver tạo); **0** Secret viết tay (`aks-verify`) |
| 4 | Cấu hình của `be` | `DB_PASSWORD` và `APPLICATIONINSIGHTS_CONNECTION_STRING` đều là `secretKeyRef`; ConfigMap `be-config` chỉ có host, tên DB, user, cổng |
| 5 | Trong git và Terraform state | `k8s/base` chỉ có chỗ giữ chỗ; `infra/aks` không đọc giá trị secret MySQL (scope của role dựng từ ID vault + tên) |

## M5 — gỡ quyền → pod không khởi động được → app gãy

`terraform -chdir=infra/aks apply -var grant_aks_keyvault_access=false` → **0 to add, 0 to change, 3 to destroy**.

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 05:00:39 | apply: 3 role assignment `Destruction complete` |
| 05:02:12 | `kubectl rollout restart deployment/be` → pod mới `be-b44f88794-pc6cz` kẹt **`ContainerCreating`** |
| 05:02:36 | event **`FailedMount`** ×6: `GET https://kv-vsf-jcip0s.vault.azure.net/secrets/mysql-admin-password/ - RESPONSE 403: 403 Forbidden … Action: 'Microsoft.KeyVault/vaults/secrets/getSecret/action' … Assignment: (not found) … "code": "ForbiddenByRbac"` |
| 05:02:27 | pod **cũ** vẫn phục vụ: `fe /api/health` → 200 (`maxUnavailable 0`) |
| 05:02:49 | xoá pod cũ (mô phỏng pod chết / node khởi động lại khi đã mất quyền) → pod thay thế cũng `ContainerCreating` |
| ~05:03:15 | **app gãy**: `GET /api/health` → **503** `{"status":"fail","be_host":"be:8080","be_status":null}` |
| 05:03:18 | trả quyền: `terraform apply` → **3 added** |
| 05:04:46 | `deployment "be" successfully rolled out` — kubelet tự thử mount lại, **không ai restart tay**; `/api/health` → 200 |
| 05:04:49 | `terraform plan` → **No changes** |

Khác App Service ở hai chỗ:

- App Service để nguyên chuỗi `@Microsoft.KeyVault(...)` trong biến môi trường và app phải tự phát hiện rồi thoát
  (`Config.cs`, `UnresolvedKeyVault`). Ở đây container **không được tạo**: lỗi nằm ở tầng nền tảng, có mã lỗi và
  tên action bị từ chối ngay trong event.
- Mất quyền **không** làm chết pod đang chạy (nó đã có secret). App chỉ gãy khi pod bị thay — đúng như bản ghi 05:02:49.
  Hệ quả vận hành: mất quyền Key Vault có thể nằm im cho tới lần deploy hoặc lần node khởi động lại kế tiếp.

## Giới hạn

- `secretObjects` chép secret sang một Secret của Kubernetes (base64 trong etcd, mã hoá at-rest do nền tảng quản).
  Ai có quyền đọc Secret trong namespace `opsboard` là đọc được mật khẩu DB — hiện chỉ người vận hành (cluster admin).
  CD **không** có quyền đó, cũng không có `pods/exec` (`infra/aks/deploy-permissions.tf`).
- CD có `deployments/write` → sửa được pod template; rủi ro còn lại ghi ở `known-issues.md`.

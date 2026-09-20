# D09 — Terraform: ACR · Key Vault · Makefile · plan trong CI (2026-09-18 → 2026-09-20)

Nhật ký đầy đủ: `notes/d9.md`. Code: `infra/app/acr.tf`, `keyvault.tf`,
`ci-permissions.tf`, phần `lifecycle` trong `app.tf`. PR: #6, #8, #9, #10, #11.

## Tóm tắt việc chính

| # | Nội dung | File Terraform |
|---|---|---|
| 1 | ACR Basic, `admin_enabled = false`, role `AcrPull` cho identity app | `acr.tf` |
| 2 | Key Vault RBAC mode, soft delete 7 ngày, purge protection tắt, 3 role assignment, secret `mysql-admin-password` | `keyvault.tf` |
| 3 | `lifecycle.ignore_changes` trên tag image (cả production + slot staging) | `app.tf` |
| 4 | `outputs.tf` mới: ACR login server, KV URI... | `outputs.tf` |
| 5 | `Makefile`: `outputs`, `check-empty` | `Makefile` |
| 6 | CI job `terraform-plan` — tự xử lý state rỗng (pha 1) lẫn full plan | `.github/workflows/ci.yml` |

## Sự cố lớn nhất: Azure throttle App Service Plan ở Southeast Asia

`make up` pha 1 (tạo `azurerm_service_plan.app`) bị Azure trả **429 Too Many
Requests** liên tục — **7 lần thử trong hơn 26 tiếng** (qua 1 đêm), lỗi
không đổi một chữ:

```
$ cat 429-throttle-error.log
```
Trích lỗi thật (file `429-throttle-error.log`):
> `App Service Plan Create operation is throttled for subscription
> 9880aa34-...-232a90f1a7bb. Please contact support if issue persists.`

**Chẩn đoán:** gọi `az appservice plan create` trực tiếp (không qua
Terraform) ở 3 vùng để tách bạch "lỗi do subscription nói chung" hay "lỗi
đặc thù 1 vùng":

| Vùng | SKU | Kết quả |
|---|---|---|
| Southeast Asia | F1 | Throttled 429 — y hệt lỗi Terraform |
| East US | F1, B1 | 0 quota (Free Trial không cấp quota compute ở vùng này — lỗi khác hẳn, không phải throttle) |
| **Central India** | **P0v3** | **Thành công** |

**Quyết định:** đổi `var.location` (App/ACR/KV) sang Central India, giữ
`var.db_location` = Southeast Asia cho MySQL (Central India không có quyền
tạo MySQL Flexible cho subscription này — lỗi `ProvisionNotSupportedForRegion`,
khác throttle).

## Apply thành công

File `apply-success.log` — `Apply complete! Resources: 20 added, 0 changed,
0 destroyed.` (cộng 5 resource pha 1 = 25 tổng từ state rỗng). Outputs:
`app_url = https://app-vsf-87z87q.azurewebsites.net`, App/ACR/KV ở
`centralindia`, `mysql_fqdn = mysql-vsf-87z87q-sea.mysql.database.azure.com`
(southeastasia).

Verify sau apply:

| Kiểm tra | Kết quả |
|---|---|
| curl production | 200 |
| curl staging | 200 |
| Firewall rule count | 18 = `app_possible_outbound_ip_count` |
| ACR `adminUserEnabled` | `false` |
| Key Vault `enableRbacAuthorization` | `true` |
| KV secret `mysql-admin-password` | tồn tại |
| `terraform plan` lần 2 | **No changes** — file `plan-no-changes.log` |

## 2 bug thật do CI phát hiện (PR #11)

Lần đầu tiên `terraform-plan` chạy **full plan** trên state có Web App thật
(mọi lần trước state luôn trống → job chỉ chạy nhánh "pha 1") — lộ ra:

1. `principal_id = data.azurerm_client_config.current.object_id` cho role
   Key Vault Secrets Officer đổi theo **ai đang chạy Terraform** → `id-gh-plan`
   (CI) chạy `plan` cũng thấy "đổi" → đòi replace → cần quyền ghi mà CI không
   có → 403. Sửa: pin cứng qua `var.secrets_writer_object_id`.
2. `azurerm_linux_web_app` refresh luôn gọi
   `Microsoft.Web/sites/config/list/action` (đọc auth settings) — role
   `Reader` không cấp hành động dạng `/action`. Thêm custom role tối thiểu 2
   action (`ci-permissions.tf`), không dùng `Website Contributor` rộng.

File `permission-fix-apply.log` — apply tạo 2 resource (role definition +
assignment), sau đó `plan` sạch cả từ local lẫn CI.

## Destroy cuối cùng

File `destroy-final.log` — `Destroy complete! Resources: 36 destroyed.`
(2026-09-20). `rg-vsf-dev` không còn tồn tại, không tốn tiền qua đêm.

## Ghi chú

- Gặp thêm 1 lần lock kẹt do lỗi mạng cục bộ giữa lúc release lock —
  `terraform force-unlock` (an toàn, xác nhận lock cùng phiên mình qua
  `Who:` trong thông báo lỗi). Chi tiết: `notes/d9.md`.
- 6 case AI-generated-sai ghi vào `ai-failure-log.md` (#5–#8) đến từ chính D9.

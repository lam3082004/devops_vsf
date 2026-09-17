# D7 — Terraform nền · remote state · OIDC (2026-09-17)

Nhật ký: `notes/d7.md` · Code: `infra/bootstrap/`, `infra/app/` · PR #4

## Hạ tầng đã dựng (bằng Terraform, không bấm Portal, không `az ... create`)

| Layer | Resource | Vòng đời |
|---|---|---|
| `infra/bootstrap` | `rg-vsf-bootstrap`, storage `stvsftffxqfgb` (+container `tfstate`), `id-gh-plan`, `id-gh-deploy`, 4 federated credential, 4 role assignment | **sống lâu**, không destroy hằng ngày |
| `infra/app` | `rg-vsf-dev`, `random_string.suffix` = `z0ierv` | destroy/apply hằng ngày từ D8 |

## Bằng chứng

| # | Nội dung | File |
|---|---|---|
| 1 | **State lock**: 2 tiến trình chạy cùng lúc, cái sau bị từ chối kèm Lock ID | `screenshots/state-lock-error-20260917-1105.png` |
| 2 | State nằm trên Azure (`app.tfstate` 2346 bytes), **không có bản local** | `screenshots/apply-complete-remote-state-20260917-1106.png` |
| 3 | CI đăng nhập Azure bằng OIDC, **không có client secret** | `oidc-login-success.log` |
| 4 | **Kiểm chứng ngược**: đổi subject sai → Entra từ chối | `oidc-wrong-subject-rejected.log` |
| 5 | PR #4 với 4/4 job xanh | `screenshots/pr4-ci-4-4-green-20260917-1152.png` |
| 6 | Lịch sử CI: 3 lần đỏ có chủ đích, 3 lần sửa rồi xanh | `screenshots/actions-history-20260917-1152.png` |

### Trích bằng chứng lock
```
Error: Error acquiring the state lock
Error message: state blob is already locked
Lock Info:
  ID:        3804055c-4376-33b6-cd10-cbc1185e5e3c
  Path:      tfstate/app.tfstate
  Operation: OperationTypeApply
  Who:       hh@hh-Inspiron-7501
```

### Trích bằng chứng OIDC (khi subject sai)
```
AADSTS700213: No matching federated identity record found for presented assertion
subject 'repo:lam3082004@67915284/devops_vsf@1371039109:pull_request'
```
Sau khi trả subject về đúng, job xanh trở lại và in ra `Azure subscription 1` cùng danh sách resource group đọc được bằng quyền Reader.

## Decision

| # | Quyết định | Lý do |
|---|---|---|
| 1 | Tách `infra/bootstrap` khỏi `infra/app` | `app` bị destroy hằng ngày; nếu state storage nằm trong đó thì Terraform xoá chính nơi chứa state của mình |
| 2 | State của bootstrap để **local, không commit** | Ngoại lệ có chủ đích của M8: bootstrap chạy một lần. Nếu mất, dùng `terraform import` (đã làm thật ở bước 2) |
| 3 | `shared_access_key_enabled = false` + `storage_use_azuread = true` | Cấm hẳn access key tĩnh; backend và provider đều xác thực bằng Entra ID. **Hai cấu hình này phải đi cặp**, thiếu một là 403 |
| 4 | `versioning_enabled` + soft delete 7 ngày trên storage state | Đường lùi khi state hỏng, thay cho việc import thủ công từng resource |
| 5 | Dùng **user-assigned MI + federated credential** thay app registration | Tenant đặt `allowedToCreateApps = false` (phát hiện từ D1) |
| 6 | **Hai** danh tính tách biệt cho CI và CD | Least privilege: plan chỉ đọc; deploy mới được ghi (role thêm ở D16) |
| 7 | Cấp `Storage Blob Data Contributor` cho `id-gh-plan` | `terraform plan` cũng **lấy lease** trên state — lease là thao tác ghi |
| 8 | Giữ **cả 2 dạng** federated credential (tên và immutable) | GitHub đang dùng immutable subject; giữ dạng tên phòng khi setting đổi. Một identity cho tối đa 20 credential |
| 9 | ID số của owner/repo đặt trong **biến**, không ghi cứng | Người khác clone chỉ cần đổi 3 biến |
| 10 | `backend "azurerm" {}` rỗng + `backend.hcl` | Cùng một code dùng cho nhiều môi trường; file này không chứa bí mật nên commit được |

## Chi phí
Storage account LRS chứa state ~2 KB → khoảng **$0.02/tháng**. Managed identity, federated credential, role assignment: **miễn phí**.

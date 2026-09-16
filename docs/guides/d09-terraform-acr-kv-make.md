# D9 — Terraform: ACR · Key Vault · Makefile · plan trong CI

**Cần:** D8 · **Chi phí:** có, tính theo giờ khi môi trường bật · **Nhật ký:** `notes/d9.md`

## Mục tiêu
Thêm registry và kho secret, nối quyền cho managed identity, gói vòng đời vào `make up` / `make down`, và cho reviewer đọc plan ngay trong PR.

## 1. ACR (`acr.tf`)

| Thuộc tính | Giá trị |
|---|---|
| Tên | `acrvsf<hậu tố>` (chỉ chữ thường + số) |
| SKU | **Basic** |
| Admin user | **tắt** (M1) |
| Public network access | bật (Basic không có private endpoint) |

Role assignment: **AcrPull** · scope = ACR · principal = `principal_id` của identity app.

## 2. Key Vault (`keyvault.tf`)

| Thuộc tính | Giá trị | Vì sao |
|---|---|---|
| Tên | `kv-vsf-<hậu tố>` (3–24 ký tự) | duy nhất toàn cầu |
| SKU | standard | |
| Mô hình quyền | **Azure RBAC** (không dùng access policy) | nhất quán với phần còn lại |
| Soft delete retention | **7 ngày** (tối thiểu) | |
| Purge protection | **tắt** | để destroy → purge → apply lại cùng tên |
| Tenant | lấy từ cấu hình client hiện tại | |

Role assignments:

| Principal | Role | Scope | Dùng để |
|---|---|---|---|
| Danh tính đang chạy Terraform (bạn / CI deploy) | **Key Vault Secrets Officer** | vault | ghi secret |
| Identity app | **Key Vault Secrets User** | vault | app đọc (M4) |
| `id-gh-plan` | Key Vault Secrets User | vault | plan refresh được secret |

Secret `mysql-admin-password` = giá trị `random_password` từ D8.
- Phụ thuộc: secret phải tạo **sau** role Secrets Officer **và** sau khi quyền kịp lan truyền → dùng phụ thuộc tường minh + một khoảng chờ ngắn (resource chờ của provider `time`) **hoặc** chấp nhận retry. Ghi Decision — thêm provider mới là thay đổi phụ thuộc, nêu lý do.

## 3. Web App không bị Terraform kéo lùi image
- Web App vẫn tạo với image placeholder.
- Thêm **lifecycle bỏ qua thay đổi** phần tên/tag image của application stack (cả app và slot) → CD (D16) đổi tag mà Terraform không đảo lại.
- Ghi vào Decision: ai sở hữu thuộc tính nào (Terraform: mọi thứ trừ tag image; CD: tag image).

## 4. Makefile

| Target | Làm gì | Ghi chú |
|---|---|---|
| `init` | init `infra/app` với backend | |
| `fmt` / `validate` | kiểm tra | giống CI |
| `plan` | plan ra file | |
| `up` | apply 2 pha (D8) | có xác nhận |
| `down` | destroy `infra/app` | **không đụng** `infra/bootstrap` |
| `outputs` | in URL, tên ACR, KV | |
| `check-empty` | liệt kê resource còn lại trong `rg-vsf-dev` (sau `down` phải trống/không tồn tại) | kỷ luật "không để qua đêm" |

Biến subscription lấy từ môi trường, Makefile **dừng lại** nếu thiếu.

## 5. CI: plan làm artifact
Thêm job `terraform-plan` (chạy sau fmt/validate, trên PR):
1. Đăng nhập Azure bằng `id-gh-plan` (OIDC).
2. `init` với backend thật.
3. `plan` → xuất **bản text** (không màu) → upload làm artifact + ghi tóm tắt (số add/change/destroy) vào job summary.
4. **Không upload file plan nhị phân** — nó chứa giá trị secret.
5. Nhóm đồng thời (concurrency) cho job Terraform để 2 PR không tranh lock.

Thêm job này vào **required checks** của ruleset.

## 6. Chạy và kiểm chứng
1. `make up` → Portal kiểm tra:
   - ACR: **Access keys → Admin user: Disabled**
   - Key Vault: **Access configuration: Azure role-based access control**; **Access control (IAM)** có 3 assignment đúng
   - Key Vault → Secrets: có `mysql-admin-password` (bạn xem được giá trị vì là Secrets Officer)
2. PR có thay đổi nhỏ → artifact plan xuất hiện, đọc được trong PR.
3. `make down` → `make check-empty`.

## Bẫy
- Tạo secret báo **403 Forbidden** ở lần apply đầu → role Secrets Officer chưa lan truyền.
- Apply lại sau destroy báo vault **đã tồn tại** → purge không chạy (thiếu feature purge, hoặc purge protection đang bật).
- Plan trong CI lỗi đọc secret → `id-gh-plan` thiếu Key Vault Secrets User.
- Gán role cho identity bị từ chối → kiểm tra 2026-09-15: role Owner của bạn **không có ABAC condition**; nếu vẫn bị từ chối, chụp lỗi nguyên văn và hỏi mentor (policy cấp management group có thể chặn).
- Tên ACR có dấu gạch → không hợp lệ.

## Tự kiểm tra
1. Vì sao chạy Terraform bằng tài khoản Owner vẫn không ghi được secret nếu thiếu role?
2. `ignore_changes` trên image giải quyết xung đột gì?
3. Vì sao không upload file plan nhị phân?

## Xong khi
- [ ] ACR admin disabled · [ ] KV RBAC + 3 role assignment · [ ] secret tạo được từ zero · [ ] `make up`/`down`/`check-empty` chạy · [ ] plan artifact trong PR, job là required check

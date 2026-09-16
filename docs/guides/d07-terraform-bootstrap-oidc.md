# D7 — Terraform nền · remote state · OIDC

**Cần:** D6 · provider `Microsoft.Storage` đã register (kiểm tra 2026-09-15: **NotRegistered**) · **Chi phí:** ~$0 (storage vài cent) · **Nhật ký:** `notes/d7.md`

> Làm trước 23/09: tự viết tay theo docs registry Terraform (provider `azurerm`). Sau 23/09 hoặc khi mentor cho: được làm cùng AI, khai báo trong PR.

## Mục tiêu
1. Nơi lưu state dùng chung, có khoá, nằm **ngoài** vòng destroy.
2. Cấu trúc Terraform chuẩn cho môi trường app.
3. GitHub Actions đăng nhập Azure **không cần secret** (OIDC).

## 1. Cấu trúc thư mục

```
infra/
  bootstrap/     tạo 1 lần: state storage + danh tính CI/CD — không bao giờ destroy hằng ngày
  app/           môi trường app — destroy/apply hằng ngày
```

Ghi Decision: vì sao tách hai thư mục (vòng đời khác nhau; destroy `app` không được xoá nơi chứa state của chính nó).

## 2. Phiên bản
- Ghim phiên bản Terraform (ghi trong cấu hình yêu cầu phiên bản) và phiên bản provider `azurerm` (nhánh 4.x) + `random`.
- **Commit file lock provider** (`.terraform.lock.hcl`) — để CI và máy bạn dùng cùng bản provider.
- Provider `azurerm` 4.x yêu cầu chỉ định subscription — truyền qua biến môi trường, không ghi cứng.

## 3. Bootstrap (`infra/bootstrap`)

| Resource | Cấu hình cần đạt | Vì sao |
|---|---|---|
| Resource group `rg-vsf-bootstrap` | Southeast Asia, tag chung | Tách vòng đời |
| Storage account (tên 3–24 ký tự thường + số, duy nhất toàn cầu) | Standard LRS · TLS tối thiểu 1.2 · **cấm truy cập blob công khai** · **bật versioning** và **soft delete blob** (7 ngày) | Lỡ hỏng state còn khôi phục được |
| Blob container `tfstate` | private | |
| Role **Storage Blob Data Contributor** trên storage cho **chính bạn** | Backend dùng xác thực Entra (không dùng access key) | Owner không có quyền data plane |

**State của bootstrap:** để local, **không commit** (có thể chứa access key của storage). Ghi vào README: "bootstrap chạy một lần, state giữ ở máy người dựng; mất thì import lại". Đây là ngoại lệ có chủ đích của M8 — ghi vào Decision.

## 4. Backend cho `infra/app`
- Backend `azurerm`: resource group, storage account, container `tfstate`, key ví dụ `app.tfstate`, **dùng xác thực Entra ID** thay vì access key.
- `init` → kiểm tra blob `app.tfstate` xuất hiện trong container sau lần apply đầu.

**Thí nghiệm lock (bằng chứng GATE):**
1. Terminal A: chạy `plan` (hoặc `apply` rồi dừng ở câu hỏi xác nhận — lock đang giữ).
2. Terminal B: chạy `plan` cùng lúc → lỗi *state blob is already locked* kèm Lock ID.
3. Portal: storage → container → blob state → **Lease state = Leased**.
4. A kết thúc → B chạy lại được. Lưu cả hai output vào `notes/d7.md`.

## 5. Nền cho `infra/app`
- Biến: `location`, `project` (`vsf`), `env` (`dev`), `owner`.
- Hậu tố ngẫu nhiên 4–6 ký tự thường (resource `random_string`) → dùng trong tên toàn cầu. Nó nằm trong state nên ổn định giữa các lần apply, **đổi khi destroy/apply lại** — chấp nhận được.
- `locals` tags: `project`, `env`, `owner`, `managed_by = terraform`.
- Provider features:
  - Key Vault: **purge khi destroy** (để apply lại cùng tên), không khôi phục vault soft-deleted tự động.
  - Resource group: cho phép xoá RG kể cả khi còn resource không do Terraform quản lý? → **không** (an toàn hơn; nếu destroy lỗi vì còn resource lạ thì đó là tín hiệu có thao tác tay).
- Resource group `rg-vsf-dev`.

## 6. OIDC cho GitHub Actions

**Đã kiểm chứng 2026-09-15 bằng Azure CLI:** chính sách tenant `allowedToCreateApps = false` → user thường **không tạo được app registration** → dùng **Đường B**. Đường A chỉ để hiểu.

| | Đường A — App registration | Đường B — User-assigned managed identity |
|---|---|---|
| Cần quyền Entra | Tạo app registration | **Không** |
| Tạo ở đâu | Entra ID | `infra/bootstrap` (Terraform) |
| Federated credential | trên app registration | trên managed identity |

**Hai danh tính, quyền khác nhau (least privilege):**

| Danh tính | Dùng cho | Subject federated credential | Role |
|---|---|---|---|
| `id-gh-plan` | CI trên PR | `repo:<owner>/<repo>:pull_request` | Reader trên subscription (hoặc RG dự án) · Storage Blob Data Contributor trên container state (plan cần ghi lease) · Key Vault Secrets User trên vault (D9 — plan phải đọc secret để refresh) |
| `id-gh-deploy` | CD trên `main` | `repo:<owner>/<repo>:ref:refs/heads/main` hoặc `repo:<owner>/<repo>:environment:production` | Thêm ở D16: AcrPush · Website Contributor (hoặc Contributor ở RG app) |

Thông số chung của federated credential: issuer của GitHub Actions token · audience mặc định cho Azure token exchange (xem docs "Configure a federated identity credential on a user-assigned managed identity").

**Phía GitHub:** lưu client ID, tenant ID, subscription ID thành **Variables** (không phải bí mật, nhưng không ghi cứng trong YAML). Workflow cần quyền **ghi id-token**.

**Kiểm chứng:** thêm vào CI một job ngắn đăng nhập Azure bằng `id-gh-plan` rồi in tên subscription → xanh. Thử đổi subject sai → đăng nhập **thất bại** (chụp — hiểu vì sao "chỉ main được deploy" được bảo đảm ở tầng danh tính).

## Bẫy
- Owner vẫn bị 403 khi `init` backend dùng Entra → thiếu role Storage Blob Data Contributor, hoặc role chưa lan truyền (chờ vài phút).
- `force-unlock` khi người khác đang chạy → hỏng state. Chỉ dùng khi chắc chắn không còn tiến trình nào.
- Commit nhầm `terraform.tfstate` của bootstrap → chứa access key.
- Subject OIDC phân biệt từng chữ: `pull_request` ≠ `ref:refs/heads/main` ≠ `environment:production`.
- ABAC condition trên role Owner của bạn (Q7) có thể chặn gán Storage Blob Data Contributor → ghi lỗi nguyên văn, hỏi mentor.

## Tự kiểm tra
1. Vì sao state storage không nằm trong `infra/app`?
2. Lock được hiện thực thế nào trên Azure Storage?
3. Vì sao plan identity cần quyền **ghi** blob dù chỉ "plan"?
4. Điều gì ngăn một PR dùng danh tính deploy?

## Xong khi
- [ ] bootstrap apply xong, state storage có versioning · [ ] `infra/app` init với remote backend · [ ] log thí nghiệm lock · [ ] CI đăng nhập Azure bằng OIDC xanh · [ ] Decision: tách bootstrap, đường OIDC A/B

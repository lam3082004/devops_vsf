# D11 — Kế hoạch chi tiết: pull ACR bằng managed identity (M1)

Guide gốc: `docs/guides/d11-container-mi.md` · Bằng chứng: `evidence/M1.md` · Nhật ký: `notes/d11.md` (tạo khi làm).
**AI:** từ D7 được sinh code. PR phải có `## AI usage`. Mọi `apply`/`destroy`/`az … create`/swap trên Azure thật cần bạn xác nhận trong phiên.

## Tình trạng đầu vào (đo 2026-09-21)

- Môi trường **đang tắt** (`rg-vsf-dev` không tồn tại, state rỗng). D11 cần bật lại: `make up` ≈ 25 phút, `make down` ≈ 20 phút.
- `app.tf` chưa có cấu hình pull bằng identity, chưa có app setting DB/Key Vault.
- App thật (`app/`, cổng **8080**, `/version`, `/health`) thoát ngay nếu thiếu `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` (`app/Infrastructure/Config.cs`) → phải làm D12 mục 1–2 **trước** khi đổi image.
- `container_port` mặc định 80 và `placeholder_image` là `appsvc/staticsite` (cổng 80) — app thật nghe 8080.
- `~/.bashrc` đã có `DOTNET_ROOT`/`PATH`. `docker` chưa dùng được trong phiên hiện tại (nhóm `docker` có `tts` nhưng phiên chưa nạp) → mở terminal mới hoặc `newgrp docker`.
- `azurerm` 4.81.0 có đủ thuộc tính: `site_config.container_registry_use_managed_identity`, `site_config.container_registry_managed_identity_client_id`, `key_vault_reference_identity_id` (cả Web App lẫn slot) — đã kiểm bằng `terraform providers schema`.

## Decisions cần bạn chốt (tôi đề xuất, chưa làm)

**A. Ai sở hữu registry URL + image?** Terraform sở hữu cờ MI + client ID; **CD/tay sở hữu cả `docker_registry_url` lẫn `docker_image_name`** → thêm `docker_registry_url` vào `ignore_changes` (hiện chỉ có image).
Lý do: nếu Terraform khai URL = ACR, lần `make up` từ rỗng sẽ pull placeholder từ ACR trống → 503, verify 200/200 của D10 hỏng. Giữ MCR làm placeholder thì `make up` vẫn ra app chạy, D11 chuyển sang ACR bằng `az webapp config container set`.
*Rủi ro chưa kiểm:* cờ `use_managed_identity=true` khi registry là MCR có làm container không khởi động không. Kiểm ở bước 3; nếu hỏng → đặt cờ bằng CLI cùng lúc với đổi registry.

**B. Placeholder cổng 8080.** Đổi `placeholder_image` → `dotnet/samples:aspnetapp` (cổng 8080; tag đã xác nhận có trên MCR) và `container_port` → 8080, để `WEBSITES_PORT` (Terraform sở hữu) đúng với cả placeholder lẫn app thật. Không đổi thì app thật đứng ở 8080 mà `WEBSITES_PORT=80` → 502 sau khi đổi image.

**C. Gộp D12 mục 1–2 vào PR này** (app settings `DB_HOST/DB_NAME/DB_USER/DB_TLS`, `DB_PASSWORD` = `@Microsoft.KeyVault(SecretUri=…)` không version, `key_vault_reference_identity_id`, `depends_on` role Secrets User). Đây là tiền đề để app thật sống; M3/M4/M5 (mục 3–5) vẫn để D12.

## Chuỗi việc

```
[0] Chuẩn bị máy ─▶ [1] PR Terraform ─▶ [2] make up ─▶ [3] verify cấu hình
                                                          │
[7] make down ◀─ [6] M1.md ◀─ [5] swap ◀─ [4] push image + đặt staging
```

### 0. Chuẩn bị máy (không tốn tiền)
- [ ] Terminal mới: `docker ps` chạy được, `dotnet --version` = 10.x, `az account show` ra đúng subscription.
- [ ] `git checkout main && git pull` — sạch, ghi lại SHA (`git rev-parse --short HEAD`) = **SHA của lần build**.

### 1. PR Terraform — `feat/d11-acr-mi-pull` (không tốn tiền)
Sửa `infra/app/app.tf`, `variables.tf` (và `locals` nếu cần):
- [ ] `site_config` của **Web App và slot**: `container_registry_use_managed_identity = true`, `container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id`.
- [ ] `ignore_changes` thêm `application_stack[0].docker_registry_url` (Decision A) — cả hai resource.
- [ ] `container_port` = 8080, `placeholder_image` = `dotnet/samples:aspnetapp` (Decision B). Sửa comment cũ nói "D11 đổi" cho khớp.
- [ ] `app_settings` (dùng chung app + slot, Decision C): `DB_HOST` = `azurerm_mysql_flexible_server.db.fqdn`, `DB_NAME` = `var.db_name`, `DB_USER` = `vsfadmin`, `DB_TLS` = `true`, `DB_PASSWORD` = `@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mysql_admin_password.versionless_id})`.
- [ ] `key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id` trên cả hai.
- [ ] `depends_on = [azurerm_role_assignment.kv_secrets_user_app]` cho cả hai (RBAC phải có trước khi app resolve).
- [ ] Kiểm cục bộ: `terraform -chdir=infra/app fmt -check`, `validate`, `plan -target=azurerm_linux_web_app.app` (state rỗng nên chỉ pha 1, giống CI). Đọc plan: **chỉ** các thuộc tính trên đổi.
- [ ] Mở PR, mục `## AI usage` ghi Claude viết đoạn nào. CI xanh (gitleaks, terraform-plan) → squash merge. Không tốn tiền.
- *Proof:* PR xanh + plan.txt.

### 2. `make up` (TỐN TIỀN — bạn gõ `yes` hai lần trong terminal, không pipe)
- [ ] Tắt Cloudflare WARP/VPN, đo nhanh `curl` tới `management.azure.com` (bài học D10).
- [ ] `make up` ≈ 25 phút, log vào `evidence/raw/d11-apply-<ngày>.log` (`make up 2>&1 | tee …`).
- [ ] Ghi thời điểm bật để nhớ `make down`.

### 3. Verify cấu hình (đọc, không tốn thêm)
- [ ] Production và staging `/` trả 200 (placeholder 8080) — nếu 503: xem Decision A rủi ro.
- [ ] `az webapp config show -g rg-vsf-dev -n <app> --query "{mi:acrUseManagedIdentityCreds,cid:acrUserManagedIdentityID}"` → `true` + client ID trùng `terraform output app_identity_client_id`; lặp lại với `--slot staging`.
- [ ] Portal → Environment variables: `DB_PASSWORD` nhãn **Key vault Reference** xanh (app và slot). Chụp (dùng chung cho D12/M4).
- [ ] `terraform plan` → **No changes**.
- *Nếu KV reference đỏ:* thường là RBAC chưa lan truyền → restart app, đợi vài phút; không sửa tay.

### 4. Push image bằng Entra + đặt staging (TỐN TIỀN nhẹ)
- [ ] `ACR=$(terraform -chdir=infra/app output -raw acr_name)`; `az acr login -n $ACR` (token Entra, **không** `--username/--password`, không `az acr update --admin-enabled`).
- [ ] `docker build --platform linux/amd64 --build-arg GIT_SHA=<sha> -t $ACR.azurecr.io/vsf-app:<sha> app/` (không tag `latest`).
- [ ] Test nhanh local: chạy container với biến giả → `/version` = `<sha>` (tuỳ chọn, tránh đốt thời gian Azure).
- [ ] `docker push …:<sha>`. Nếu bị `unauthorized`: thêm `AcrPush` cho `var.secrets_writer_object_id` qua Terraform (PR nhỏ), ghi vào `notes/d11.md`.
- [ ] Portal → ACR → Repositories thấy `vsf-app:<sha>`. Chụp.
- [ ] Đặt image staging (bạn xác nhận): `az webapp config container set -g rg-vsf-dev -n <app> --slot staging --container-image-name $ACR.azurecr.io/vsf-app:<sha> --container-registry-url https://$ACR.azurecr.io`. Sau lệnh, kiểm lại hai cờ MI ở bước 3 **vẫn còn** (lệnh này có thể ghi đè).
- [ ] Log stream staging: pull → start → JSON `startup`. `curl staging/version` = `<sha>`. `curl staging/health` → ghi kết quả (200 nếu DB ổn; 503 chưa phải lỗi M1, ghi cho D12).

### 5. Swap (bạn xác nhận — Azure thật)
- [ ] `az webapp deployment slot swap -g rg-vsf-dev -n <app> --slot staging --target-slot production`.
- [ ] `curl prod/version` = `<sha>` kèm thời gian. Kiểm cờ MI trên production sau swap.
- [ ] `terraform plan` → No changes (nhờ `ignore_changes`).

### 6. `evidence/M1.md` + notes
6 bằng chứng theo guide mục 4: ACR admin Disabled · cờ MI + client ID · AcrPull trên ACR · log pull · `/version`=SHA · không username/password trong app settings. Kèm luồng: App Service → token user-assigned MI → ACR data plane → pull. Trả lời 3 câu tự kiểm tra bằng lời của bạn.
- [ ] `notes/d11.md`, tick plan, `ai-failure-log.md` nếu AI sinh sai gì.
- **Chứng minh ngược (gỡ AcrPull → pull fail):** để **cùng phiên D12 M5** cho khỏi bật môi trường thêm lần nữa; nếu làm ngay ở D11 thì cần thêm PR biến tắt role — không làm trong buổi này trừ khi bạn muốn.

### 7. Cuối buổi
- [ ] `make down` (≈ 20 phút, bạn gõ `yes`), rồi `make check-empty`. Không để chạy qua đêm.

## Tự kiểm tra (nói lại bằng lời, không đọc)
1. Vì sao phải chỉ định client ID? · 2. Token pull lấy ở đâu, gửi tới control plane hay data plane? · 3. Bật lại admin user thì M1 sai ở điểm nào dù app vẫn chạy?
4. Vì sao `docker_registry_url` cũng phải `ignore_changes`? Điều gì xảy ra với `make up` từ rỗng nếu không?

## Rủi ro
| Rủi ro | Tín hiệu | Xử lý |
|---|---|---|
| Cờ MI + registry MCR làm placeholder không lên | bước 3: 503 | đặt cờ bằng CLI lúc đổi registry (bước 4), sửa Decision A |
| KV reference đỏ lúc đầu | Portal đỏ | restart, chờ RBAC; không đổi role tay |
| `az … container set` xoá cờ MI | bước 4 kiểm lại | đặt lại bằng `az webapp config set` hoặc apply |
| AcrPush thiếu | `unauthorized` khi push | PR thêm role, ghi lại |
| Lệnh Terraform đứt giữa chừng | như D10 | **đọc trước** (lock, state, plan) rồi mới chạy lại — `notes/d10.md` |
| 429 tạo App Service Plan | như D9 | `notes/d9.md` |

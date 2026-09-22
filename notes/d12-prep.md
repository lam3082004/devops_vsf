# D12 — Kế hoạch chi tiết: Key Vault reference · MySQL · app gãy khi mất quyền (M3, M4, M5)

Guide gốc: `docs/guides/d12-keyvault-mysql.md` · Bằng chứng: `evidence/M3.md`, `evidence/M4.md`, `evidence/M5.md` · Nhật ký: `notes/d12.md` (tạo khi làm).
**AI:** từ D7 được sinh code. PR phải có mục `## AI usage`. Mọi `apply`/`destroy`/`az … create`/restart trên Azure thật cần bạn xác nhận trong phiên.

## Tiến độ

| Bước | Trạng thái |
|---|---|
| 0. Chuẩn bị máy | ☐ bạn làm đầu phiên D12 (tắt WARP, terminal mới, `az group list`) |
| 1. PR-A đưa D11 vào `main` | ✅ **xong 2026-09-22** — PR #18 squash merge, CI 5/5 xanh, `main` = `eeddb4e`. Việc chặn B1 đã gỡ |
| 2. PR-B hai biến toggle role | ✅ **xong 2026-09-22** — PR #20, `fmt` + `validate` sạch |
| — kế hoạch này | ✅ PR #19 merge vào `main` (`2fde140`) |
| 0. Worktree sạch | ✅ **xong 2026-09-22** — `.claude/worktrees/d12` dựng từ `main`, xác nhận `app/Dockerfile` có mặt → việc chặn B2 đã gỡ. Còn lại của bước 0 (tắt WARP, kiểm `docker`/`dotnet`/`az`) là việc đầu phiên |
| Khung bằng chứng | ✅ **xong 2026-09-22** — `evidence/M3.md`, `M4.md`, `M5.md`, `notes/d12.md`, `evidence/d12/screenshots/` |
| Script gom bằng chứng M3+M4 | ✅ **xong 2026-09-22** — `scripts/d12-verify.sh`, shellcheck sạch, đã thử cả 2 nhánh tiền kiểm |
| 3–10 | ☐ phiên D12, cần môi trường bật (~2 tiếng, ≈ $0.26) |

Cả hai việc chặn đã gỡ. Phần còn lại **bắt buộc phải có bạn ở terminal**: `make up`
hỏi `yes` tương tác, `terraform apply` / `az webapp restart` / swap bị bộ lọc Claude
Code chặn (D11 đã gặp), và ảnh Portal chỉ bạn chụp được.

## Tình trạng đầu vào (đo 2026-09-22, chỉ đọc)

- **Môi trường đang TẮT.** `az group list` chỉ còn `rg-vsf-bootstrap` + 2 RG mặc định của Azure → `make down` cuối D11 đã chạy xong, không tốn tiền qua đêm. D12 phải bật lại: `make up` ≈ 25 phút, `make down` ≈ 20 phút.
- **Mục 1–2 của guide D12 đã viết xong từ D11** (commit `c710815`): `local.app_settings` có `DB_HOST/DB_NAME/DB_USER/DB_TLS` + `DB_PASSWORD = @Microsoft.KeyVault(SecretUri=…versionless_id)`, `key_vault_reference_identity_id` = user-assigned MI, `depends_on` role Secrets User — dùng chung cho **cả app lẫn slot**. Đã đo thật lúc D11: reference **Resolved** cả 2 slot.
- **Mục 3 (firewall) đã đúng từ D8:** `azurerm_mysql_flexible_server_firewall_rule.app_outbound` `for_each` trên `possible_outbound_ip_address_list` (`infra/app/db.tf:76`), không có rule "allow Azure services", không có IP máy.
- **Mục 5 chưa có đường gỡ quyền bằng Terraform:** `azurerm_role_assignment.kv_secrets_user_app` (`infra/app/keyvault.tf:43`) và `azurerm_role_assignment.acr_pull` (`infra/app/acr.tf:17`) đang gán vô điều kiện, không có biến bật/tắt.
- **Bằng chứng đã có sẵn, dùng lại được:**
  - M3 thô: POST/GET `/items` trên production 18:29 ngày 21/09 (`notes/d11.md`, mục "Chuẩn bị D12"). Database đã bị xoá cùng `make down` → chạy lại sẽ ra `id` mới; giữ bản cũ làm lần đo thứ nhất, lấy thêm bản mới kèm ảnh Log stream.
  - M4: ảnh `evidence/d11/screenshots/07-env-vars-production.png` và `08-env-vars-staging.png` (đã che email).
  - M1 còn nợ đúng một ô: **chứng minh ngược AcrPull** — cố ý hoãn sang phiên này để khỏi bật môi trường thêm lần nữa.
- Máy: `~/.bashrc` đã có `DOTNET_ROOT`/`PATH`; nhóm `docker` đã có `tts`. Cloudflare WARP là thủ phạm 4+ lần đứt mạng ở D10/D11 → **tắt trước mọi lệnh Terraform**.

## Hai việc CHẶN, phải xử lý trước khi tiêu tiền

**B1 — 5 commit của D11 chưa vào `main`.**
`c710815 · 1c6c4a2 · 44bb3fd · 145fb19 · 8fd1169` đang nằm trên `feat/d11-acr-mi-pull` (worktree `.claude/worktrees/docs-d10-close-d11-plan`). `make up` từ `main` sẽ dựng hạ tầng **trước D11**: không cờ MI, không app settings DB, không Key Vault reference → toàn bộ tiền đề của D12 biến mất, và lặp lại đúng lỗi "apply nhầm code `main`" đã ghi ở `ai-failure-log.md` #11.

**B2 — checkout chính đang bẩn và trộn hai việc.**
`git status` ở checkout chính có refactor OpsBoard chưa commit (`app/` → `app/be`, thêm `app/fe`, sửa `ci.yml`, `Makefile`, `README.md`, `.gitignore`, `docker-compose.yml`, `CLAUDE.md`) lẫn với sửa tài liệu D11 (`ai-failure-log.md`, `known-issues.md`, plan). Hệ quả cụ thể cho D12: trên đĩa **`app/Dockerfile` đã bị đổi tên thành `app/be/Dockerfile`**, nên `docker build … app/` ở checkout chính sẽ hỏng. → Làm D12 trong **worktree sạch** tách khỏi mớ đó.

## Decisions cần bạn chốt (tôi đề xuất, chưa làm)

**A. Đưa D11 vào `main` bằng PR** từ `feat/d11-acr-mi-pull`, squash merge, mục `## AI usage` ghi Claude viết `app.tf`/`variables.tf`. Luật project cấm push thẳng `main`; `notes/d11.md` cũng đã tự ghi nhận "lệch luật có chủ đích" cần trả lại. Tách riêng, **không** kèm refactor OpsBoard.

**B. M5 gỡ quyền bằng biến Terraform, không gỡ tay Portal.** Thêm `var.grant_app_keyvault_access` (mặc định `true`) điều khiển `count` của `kv_secrets_user_app`; đặt `false` → apply → role biến mất; trả lại bằng `true` → apply. Lý do: guide cho phép cả hai nhưng gỡ tay tạo drift phải nhớ xoá, còn cách này **drift = 0** và bước "trả role" chỉ là một lần apply. Thêm luôn `var.grant_app_acr_pull` cùng cơ chế để trả nốt ô chứng minh ngược của M1 trong cùng phiên.

**C. Image build từ `main` sau khi merge D11** (app NodeRegistry hiện tại, cổng 8080) — **không** kéo refactor OpsBoard chưa xong vào. Lý do: `/items` của bản này đã chạy thật trên Azure ở D11, còn bản OpsBoard đòi header `X-User-Name` và schema ticket mới, chưa từng chạy trên Azure. D12 là bài về Key Vault/MySQL/quyền, không phải bài về app.

**D. Đặt image thẳng trên production, không swap.** M2 (swap) đã có bằng chứng đầy đủ ở D11 lúc 18:08; D12 không yêu cầu slot. Bỏ swap tiết kiệm ~10 phút môi trường bật. Slot staging vẫn chạy placeholder — Key Vault reference của staging vẫn resolve được (nền tảng resolve, không phụ thuộc image) nên ảnh M4 của staging vẫn hợp lệ.

## Chuỗi việc

```
[0] chuẩn bị ─▶ [1] PR-A: D11 vào main ─▶ [2] PR-B: 2 biến toggle role      (không tốn tiền)
                                                  │
[3] make up ─▶ [4] push image + đặt container production ─▶ [5] M3 ─▶ [6] M4
                                                                        │
[10] make down ◀─ [9] plan No changes + viết evidence ◀─ [8] M1 ngược ◀─ [7] M5
```

Ước lượng thời gian môi trường BẬT: 25' up + 10' image + 10' M3 + 5' M4 + 30' M5 + 20' M1 ngược + 5' plan + 20' down ≈ **2 tiếng**. Chi phí ≈ 2 tiếng × (P0v3 0.0915 + MySQL B1ms 0.026 + ACR Basic 0.0069/giờ) ≈ **$0.26**.

---

### 0. Chuẩn bị (không tốn tiền)

- [ ] Tắt Cloudflare WARP. Kiểm: `for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code} " https://management.azure.com/; done` → 10/10 có phản hồi (401 là bình thường; quan trọng là không timeout).
- [ ] Terminal mới: `docker ps` chạy không cần sudo, `dotnet --version` ra 10.x, `az account show` đúng subscription.
- [ ] Xác nhận môi trường còn tắt: `az group list -o table` → **không có** `rg-vsf-dev`.
- [ ] Tạo worktree sạch cho D12 (giải B2), mọi lệnh của bài này chạy trong đó:
      `git worktree add .claude/worktrees/d12 -b feat/d12-kv-role-toggle main`

### 1. PR-A — đưa D11 vào `main` — ✅ XONG 2026-09-22

- [x] Kiểm nhánh: đúng 5 commit, diff chỉ `infra/app/{app,variables}.tf` + `evidence/M1.md` + 9 ảnh `evidence/d11/` + `notes/d11.md`, **không** lẫn file refactor OpsBoard.
- [x] Push nhánh, mở **PR #18** có mục `## AI usage`.
- [x] CI **5/5 xanh**: gitleaks · dotnet (format, build, test) · terraform (fmt, validate) · terraform plan (infra/app) · azure login (OIDC).
- [x] Squash merge → `main` = **`eeddb4e`**. Việc chặn B1 đã gỡ.
- [ ] **Bạn làm đầu phiên D12:** `git checkout main && git pull` ở checkout chính (an toàn: 2 commit mới không đụng file nào đang sửa dở của refactor OpsBoard), rồi `git rev-parse --short HEAD` — **SHA đó là tag image của phiên**.
- *Lưu ý còn nguyên:* `ai-failure-log.md` #11, `known-issues.md` và bản cập nhật plan của D11 vẫn nằm ở checkout chính lẫn với OpsBoard → khi commit phải `git add` từng file, tuyệt đối không `git add -A`.

### 2. PR-B — hai biến bật/tắt role (Decision B) — ✅ XONG 2026-09-22

- [x] `infra/app/variables.tf`: thêm `grant_app_keyvault_access` và `grant_app_acr_pull` (`bool`, mặc định `true`), kèm khối comment nói rõ: chỉ đặt `false` bằng `-var` trên dòng lệnh đúng một lần đo, apply lại không có `-var` để trả quyền, và `plan` sau đó phải ra No changes.
- [x] `infra/app/keyvault.tf:43`: `kv_secrets_user_app` thêm `count = var.grant_app_keyvault_access ? 1 : 0`.
- [x] `infra/app/acr.tf:17`: `acr_pull` thêm `count = var.grant_app_acr_pull ? 1 : 0`.
- [x] **Bẫy `count` + `depends_on` — đã kiểm:** `grep -rn "kv_secrets_user_app\|acr_pull" infra/` chỉ ra 2 chỗ dùng là `depends_on` ở `app.tf:61` và `app.tf:121`. `depends_on` trỏ cả tập resource nên tập rỗng vẫn hợp lệ → **không phải sửa**; không chỗ nào dùng `.id` nên không cần đổi thành `[0].id`.
- [x] `terraform -chdir=infra/app fmt -check -diff` → không có khác biệt; `terraform validate` → **Success! The configuration is valid.**
- [x] PR **#20** có `## AI usage`.
- *Proof:* `validate` xanh + job `terraform plan (infra/app)` trong CI. Với mặc định `true`, plan ở bước 3 phải ra đúng số resource như D11 — hai biến này không đổi gì khi chưa ai đặt `false`.

### 3. `make up` (TỐN TIỀN — bạn tự gõ `yes`, không pipe)

- [ ] Chạy **trong worktree D12 đã rebase lên `main` mới** — `pwd` trước khi gõ lệnh (bài học `ai-failure-log.md` #11).
- [ ] `make up 2>&1 | tee evidence/raw/d12-apply-2026-09-22.log` ≈ 25 phút, 2 pha (pha 1 `-target` Web App, pha 2 toàn bộ).
- [ ] **Ghi giờ bật** vào `notes/d12.md` ngay — để nhớ `make down`.
- [ ] `terraform -chdir=infra/app output` → lưu `acr_name`, tên web app, FQDN MySQL.
- [ ] Kiểm nhanh: production + staging `/` trả 200 (placeholder `aspnetapp` cổng 8080).

### 4. Image thật lên production (Decision C + D)

- [ ] `ACR=$(terraform -chdir=infra/app output -raw acr_name)`; `az acr login -n $ACR` → `Login Succeeded` (token Entra, **không** admin user).
- [ ] `SHA=$(git rev-parse --short HEAD)`
- [ ] `docker build --platform linux/amd64 --build-arg GIT_SHA=$SHA -t $ACR.azurecr.io/vsf-app:$SHA app/` (không tag `latest`).
- [ ] `docker push $ACR.azurecr.io/vsf-app:$SHA` — lưu digest.
- [ ] `az webapp config container set -g rg-vsf-dev -n <app> --container-image-name $ACR.azurecr.io/vsf-app:$SHA --container-registry-url https://$ACR.azurecr.io` (**không** `--slot`: đặt thẳng production).
- [ ] **Kiểm lại ngay** hai cờ MI sau lệnh này. D11 cho thấy `az webapp config show` trả `null` cho client id dù cấu hình đúng → đọc bằng `az resource show … --resource-type Microsoft.Web/sites/config --name <app>/web`. Kỳ vọng: `acrUseManagedIdentityCreds = true`, `acrUserManagedIdentityID` = `terraform output app_identity_client_id`.
- [ ] Chờ container khởi động rồi `curl -s https://<app>.azurewebsites.net/version` → `{"sha":"<SHA>"}`.
- *Nếu 503 kéo dài:* xem Log stream. Hai nguyên nhân đã gặp: `WEBSITES_PORT` lệch cổng, và role AcrPull chưa lan truyền.

### 5. M3 — `/items` đọc ghi MySQL

> **Nhanh hơn:** `bash scripts/d12-verify.sh` chạy một lượt toàn bộ lệnh chỉ đọc của
> M3 + M4 (và nhắc lại cờ MI của M1), lưu log vào `evidence/raw/d12-verify-<ngày>.log`.
> Script tự tra tên resource từ `terraform output` nên không phải điền suffix bằng tay,
> và dừng sớm với thông báo rõ nếu chưa `make tf-init` hoặc môi trường đang tắt.
> Phần dưới là từng lệnh rời, dùng khi cần chạy lại một ô lẻ.

- [ ] `curl -s -w '\n%{http_code}\n' https://<app>.azurewebsites.net/health` → 200 `{"status":"ok","db":"ok"}`.
- [ ] `TS=$(date +%H%M%S)`; `curl -s -X POST …/items -H 'content-type: application/json' -d "{\"name\":\"d12-check-$TS\"}"` → **201** kèm `id`, `last_seen_at`.
- [ ] `curl -s …/items` → **200**, thấy bản ghi vừa tạo.
- [ ] Portal → Web App → **Log stream**: chụp log JSON của đúng 2 request trên → `evidence/d12/screenshots/`.
- [ ] Firewall: `az mysql flexible-server firewall-rule list -g rg-vsf-dev -n <mysql> -o table` → **chỉ** các rule `app-outbound-*`; số rule = số phần tử `az webapp show … --query possibleOutboundIpAddresses` (D8 ra 20/20). Không `0.0.0.0` (allow Azure services), không IP máy bạn. Chụp Portal MySQL → Networking.
- [ ] Viết `evidence/M3.md`: 3 output curl có giờ + 2 ảnh + bảng đối chiếu số rule; kèm kết quả 18:29 ngày 21/09 làm lần đo thứ nhất.

### 6. M4 — không secret plaintext

- [ ] Rà **toàn bộ** app settings bằng CLI, không chỉ nhìn ảnh:
      `az webapp config appsettings list -g rg-vsf-dev -n <app> -o table` và bản `--slot staging`.
      Kỳ vọng đúng 7 khoá: `WEBSITES_PORT`, `WEBSITES_ENABLE_APP_SERVICE_STORAGE`, `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_TLS`, `DB_PASSWORD`. Chỉ `DB_PASSWORD` là secret, và giá trị là chuỗi `@Microsoft.KeyVault(SecretUri=…)` — **không** có version ở cuối URI.
- [ ] Connection strings rỗng: `az webapp config connection-string list -g rg-vsf-dev -n <app>` → `[]`.
- [ ] Portal → Environment variables: `DB_PASSWORD` nhãn **Key vault Reference** + **Resolved** (xanh), cả 2 slot → ảnh mới cho D12 (ảnh D11 `07`/`08` là lần đo thứ nhất).
- [ ] Viết `evidence/M4.md`: bảng 7 khoá + kết luận "0 secret plaintext" + `az acr show -n $ACR --query adminUserEnabled` → `false` + MI có đúng 2 role (`AcrPull` trên ACR, `Key Vault Secrets User` trên vault).

### 7. M5 — chứng minh ngược Key Vault (bài chính của D12)

Ghi **giờ từng bước** vào bảng trong `evidence/M5.md` khi làm.

| # | Việc | Kỳ vọng |
|---|---|---|
| 0 | `/health` + `/items` | 200 (đã có ở bước 5, ghi lại giờ) |
| 1 | `terraform -chdir=infra/app apply -var 'grant_app_keyvault_access=false'` (**bạn xác nhận**) | `1 to destroy` — đúng role assignment, không gì khác |
| 2 | `az role assignment list --assignee <principal-id-MI> --scope <kv-id> -o table` | rỗng. Thêm Portal → Key Vault → IAM → **Check access** cho MI: không còn quyền **kế thừa** từ RG/subscription (bẫy trong guide) |
| 3 | Chờ 5–10 phút cho RBAC lan truyền | |
| 4 | `az webapp restart -g rg-vsf-dev -n <app>` (**bạn xác nhận**) — bắt buộc, vì giá trị reference đang được cache | |
| 5 | Portal → Environment variables | `DB_PASSWORD` báo lỗi tham chiếu (đỏ) → **chụp** |
| 6 | Portal → Log stream | log `fatal` về `DB_PASSWORD` rồi container thoát, restart lặp → **chụp** |
| 7 | `curl -s -o /dev/null -w '%{http_code}' …/health` | **không phải 200** (503/502) → lưu output |
| 8 | `terraform -chdir=infra/app apply` (biến về mặc định `true`) (**bạn xác nhận**) | `1 to add` |
| 9 | Chờ lan truyền + `az webapp restart` | |
| 10 | Environment variables + `/health` + `/items` | xanh lại, 200 → chụp |

- [ ] Viết `evidence/M5.md`: bảng trên có giờ thật + 4 ảnh (bước 5, 6, 7, 10) + **giải thích vì sao gỡ quyền không làm app gãy ngay**: App Service cache giá trị đã resolve của Key Vault reference và token của MI còn hạn; app chỉ đọc lại biến môi trường khi container khởi động → không restart thì bản đang chạy vẫn dùng mật khẩu đã cache. Đây đúng là bẫy #1 của guide ("tưởng M5 thất bại").
- [ ] Trả lời 3 câu **Tự kiểm tra** của guide vào cuối `M5.md` (câu 3 dẫn sang S3 Private Endpoint).

### 8. M1 — chứng minh ngược AcrPull (ô còn nợ của D11)

- [ ] `terraform … apply -var 'grant_app_acr_pull=false'` (**bạn xác nhận**) → `1 to destroy`.
- [ ] Chờ lan truyền → `az webapp restart` → Log stream: lỗi pull image (`unauthorized` / `DockerApiException`), site không lên → chụp.
- [ ] `terraform … apply` (về `true`) → restart → `/version` 200 lại.
- [ ] Điền vào đúng ô "chứng minh ngược" đang trống trong `evidence/M1.md`, ảnh để ở `evidence/d12/screenshots/` và ghi rõ chụp ở phiên D12.
- *Thứ tự:* làm **sau** M5 — nếu ACR hỏng trước thì container không lên và không quan sát được lỗi Key Vault.

### 9. Đóng bài (không tốn thêm)

- [ ] `terraform -chdir=infra/app plan` → **No changes** (chứng minh đã xoá sạch drift của bước 7–8; bẫy cuối guide).
- [ ] Che email/ID nhạy cảm trong mọi ảnh trước khi commit (bài học D11: ảnh IAM lộ email 2 lần).
- [ ] Viết `notes/d12.md` (diễn biến theo giờ, sai sót, AI usage), cập nhật `docs/plans/active/azure-app-service-internship.md` mục Recovery + checklist D12, tick "Xong khi" trong guide.
- [ ] Mỗi lần AI sinh sai → 1 dòng `ai-failure-log.md`.
- [ ] PR-C: evidence + notes + plan → squash merge.

### 10. `make down` (việc bắt buộc cuối phiên)

- [ ] **Kiểm WARP đã tắt trước khi destroy** — destroy đứt giữa chừng đắt hơn plan đứt nhiều (D11).
- [ ] `make down 2>&1 | tee evidence/raw/d12-destroy-2026-09-22.log` ≈ 20 phút.
- [ ] `az group list -o table` → không còn `rg-vsf-dev`.

---

## Bẫy đã biết (từ D10, D11 và guide)

| Bẫy | Dấu hiệu | Xử lý |
|---|---|---|
| Chạy Terraform nhầm thư mục | `plan` ra thay đổi lạ | `pwd` trước mỗi lệnh; `ai-failure-log.md` #11 |
| `az webapp config show` trả `null` cho `acrUserManagedIdentityID` | tưởng mất cấu hình | đọc bằng `az resource show … /config/web` |
| Đứt mạng giữa `plan`/`apply` → lease mồ côi trên `app.tfstate` | mọi lệnh treo ở "Acquiring state lock"; metadata rỗng nên `force-unlock` vô dụng | `az storage blob lease break --account-name stvsftffxqfgb --container-name tfstate --blob-name app.tfstate --auth-mode login` (bạn chạy, Claude Code chặn) |
| Gỡ quyền mà không restart | app vẫn 200 → tưởng M5 hỏng | bước 4 của bảng M5 là bắt buộc |
| Role kế thừa từ RG/subscription | gỡ ở vault mà app vẫn đọc được | Portal → KV → IAM → **Check access** cho MI |
| Tham chiếu Key Vault có version | xoay vòng secret không có hiệu lực | đã dùng `versionless_id`, kiểm lại ở bước 6 |
| Quên apply trả role | `plan` hôm sau thấy drift | bước 9 `plan` No changes |
| `docker build app/` hỏng ở checkout chính | `app/Dockerfile` không tồn tại (đã đổi tên trên đĩa) | làm trong worktree sạch (B2) |

## Việc còn nợ từ D11 mà D12 phải gánh

- [ ] Đưa 5 commit D11 vào `main` (bước 1) — trả lại "lệch luật có chủ đích" đã ghi ở `notes/d11.md`.
- [ ] Chứng minh ngược AcrPull cho M1 (bước 8).

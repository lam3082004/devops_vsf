# devops_vsf — OpsBoard trên Azure App Service

Ứng dụng ticket hai service (`fe` Next.js + `be` .NET 10) chạy container trên Azure App Service, MySQL Flexible, ACR,
Key Vault; hạ tầng 100% Terraform; CI/CD trunk-based trên GitHub Actions bằng OIDC, deploy qua slot `staging` rồi swap.
Sơ đồ traffic và quyền: [`architecture.md`](architecture.md). Đề bài: [`topic.md`](topic.md).

README này dành cho **người thứ ba dựng lại hệ thống từ đầu**. Nó đã được kiểm bằng cách làm theo từng bước từ một
clone mới ngày 2026-10-01 (`evidence/M8.md` mục "Lần cuối (D24)").

## Tài liệu

| Cần | Đọc |
|---|---|
| Dựng / deploy | README này |
| Kiến trúc, danh tính → role → scope | [`architecture.md`](architecture.md) |
| Vận hành hằng ngày, alert, dashboard, KQL | [`runbook.md`](runbook.md) · [`docs/logging.md`](docs/logging.md) |
| Rollback / phục hồi | [`docs/rollback.md`](docs/rollback.md) · drill: [`docs/drills/`](docs/drills/) |
| Lỗi đã gặp, việc chưa xong | [`known-issues.md`](known-issues.md) |
| Kết quả kiểm thử | [`test-report.md`](test-report.md) · bằng chứng M1–M11: [`evidence/README.md`](evidence/README.md) |
| Chi phí | [`cost-report.md`](cost-report.md) |
| AI sinh sai | [`ai-failure-log.md`](ai-failure-log.md) |
| Nhật ký từng ngày · hướng dẫn từng bài | `notes/dXX.md` · [`docs/guides/`](docs/guides/README.md) |
| Ứng dụng (PRD, API, schema, chạy local) | [`docs/docs_app/`](docs/docs_app/README.md) |

## 1. Chuẩn bị

**Azure:** một subscription mà bạn là **Owner** (cần gán role cho managed identity). Tenant không cần cho tạo app
registration: mọi danh tính ngoài Azure là user-assigned MI + federated credential. Register các resource provider
(chỉ một lần, mỗi lệnh vài phút):

```bash
PROVIDERS="Microsoft.Web Microsoft.DBforMySQL Microsoft.ContainerRegistry Microsoft.KeyVault
  Microsoft.ManagedIdentity Microsoft.OperationalInsights Microsoft.Insights Microsoft.Storage Microsoft.AlertsManagement"
for p in $PROVIDERS; do az provider register --namespace "$p"; done
for p in $PROVIDERS; do printf '%s\t%s\n' "$p" "$(az provider show -n "$p" --query registrationState -o tsv)"; done   # cả 9 phải Registered
```

Region: App Service, ACR, Key Vault ở **Central India**; MySQL ở **Southeast Asia** (`infra/app/variables.tf`,
lý do ở `known-issues.md` #6, #27). Subscription khác có thể không bị các giới hạn này, nhưng đừng đổi nếu chưa cần.

**Công cụ** (phiên bản đã dùng; CI ghim cùng số trong `.github/workflows/ci.yml`):

| Công cụ | Phiên bản | Dùng cho |
|---|---|---|
| Terraform | 1.15.x (CI: 1.15.8; `required_version = "~> 1.15"`) | `infra/` |
| Azure CLI | ≥ 2.60 (đã dùng 2.90.0) | đăng nhập, bootstrap, kiểm tra |
| GitHub CLI `gh` | ≥ 2.40 | biến, environment, PR |
| Docker | 24+ | build image local (không bắt buộc, CD build trên runner) |
| .NET SDK | 10.0 | `make test` / `make lint`. Nếu `dotnet` báo `[/usr/lib/dotnet/host/fxr] does not exist` (gói dotnet của distro hỏng), cài bằng `dotnet-install.sh` vào `~/.dotnet` rồi đặt `DOTNET_ROOT=~/.dotnet` và thêm vào `PATH` |
| Node.js | 24 (Next 16 cần ≥ 20) | `make fe-*` |
| gitleaks | 8.30.1 | pre-commit hook: `bash scripts/install-hooks.sh` |
| Trivy | 0.74.0 | quét image local (CI/CD quét lại) |
| `jq`, `curl` | bất kỳ | script trong `scripts/` |

```bash
terraform version && az version -o tsv --query '"azure-cli"' && gh --version | head -1 && dotnet --version && node --version
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)   # Terraform, Makefile và backend đều đọc biến này
bash scripts/install-hooks.sh
```

## 2. Bootstrap (một lần cho mỗi subscription)

`infra/bootstrap` tạo `rg-vsf-bootstrap`: storage chứa state Terraform của `infra/app` và 3 danh tính cho GitHub
(`id-gh-plan` cho CI, `id-gh-deploy` cho CD, `id-agent-triage` cho agent đọc sự cố). State của **chính** bootstrap để local
(nó tạo ra storage chứa state, không tự lưu vào đó được).

> **Bootstrap đã có sẵn (máy mới, clone mới, người khác trong nhóm)?** Đừng apply. State bootstrap là file local nên clone mới
> **không có** state: `plan` sẽ ra `21 to add` (đo 01/10, trước khi thêm 2 credential `drift-check`), apply lúc đó tạo trùng danh tính hoặc gãy vì tên đã tồn tại.
> Khôi phục state từ bản sao lưu (bước 3) rồi `plan` phải ra **No changes**:
>
> ```bash
> install -m 600 ~/vsf-state-backup/bootstrap-<ngày mới nhất>.tfstate infra/bootstrap/terraform.tfstate
> terraform -chdir=infra/bootstrap init && terraform -chdir=infra/bootstrap plan    # No changes
> ```
>
> Mất cả bản sao lưu: dựng lại bằng `import` như D23 (`notes/d23.md`), cẩn thận `random_string.suffix`.

1. Repo GitHub của bạn: fork/clone repo này về tài khoản của bạn, rồi lấy ID số (cần cho federated credential, vì repo
   GitHub mặc định gửi subject OIDC kèm ID số — `ai-failure-log.md` #4):

   ```bash
   gh api user --jq .id                     # → github_owner_id
   gh api repos/<owner>/<repo> --jq .id     # → github_repo_id
   gh api repos/<owner>/<repo>/actions/oidc/customization/sub   # use_immutable_subject: true/false — code khai cả hai dạng
   ```

2. Apply bootstrap (biến trùng tên trong `infra/bootstrap/variables.tf`; mặc định là repo của tác giả):

   ```bash
   cat > infra/bootstrap/terraform.tfvars <<EOF      # gitignored
   github_repo     = "<owner>/<repo>"
   github_owner_id = "<số>"
   github_repo_id  = "<số>"
   EOF
   terraform -chdir=infra/bootstrap init
   terraform -chdir=infra/bootstrap plan      # đọc kỹ: 23 to add, 0 to destroy
   terraform -chdir=infra/bootstrap apply
   terraform -chdir=infra/bootstrap output
   ```

3. **Sao lưu state bootstrap ra ngoài repo ngay** (state này local, mất thư mục là mất state — `known-issues.md` #17):

   ```bash
   mkdir -p -m 700 ~/vsf-state-backup && install -m 600 infra/bootstrap/terraform.tfstate ~/vsf-state-backup/bootstrap-$(date +%F).tfstate
   ```

4. Trỏ backend của `infra/app` vào storage vừa tạo: sửa `storage_account_name` trong `infra/app/backend.hcl` bằng
   `terraform -chdir=infra/bootstrap output -raw storage_account_name` (file này commit được: không có key).

5. GitHub: biến repo (không phải secret, không có giá trị nào bí mật):

   ```bash
   B="terraform -chdir=infra/bootstrap output -raw"
   gh variable set AZURE_TENANT_ID        --body "$($B tenant_id)"
   gh variable set AZURE_SUBSCRIPTION_ID  --body "$($B subscription_id)"
   gh variable set AZURE_CLIENT_ID_PLAN   --body "$($B gh_plan_client_id)"
   gh variable set AZURE_CLIENT_ID_DEPLOY --body "$($B gh_deploy_client_id)"
   gh variable set AZURE_AGENT_CLIENT_ID  --body "$($B agent_triage_client_id)"
   ```

6. GitHub: 4 environment, mỗi cái chỉ nhận nhánh `main` (subject OIDC của job có environment là
   `environment:<tên>`, federated credential khai đúng 4 tên này):

   ```bash
   R=repos/<owner>/<repo>
   for env in staging-deploy production agent-triage drift-check; do
     echo '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' \
       | gh api -X PUT "$R/environments/$env" --input -
     gh api -X POST "$R/environments/$env/deployment-branch-policies" -f name=main -f type=branch
   done
   ```

7. GitHub: ruleset `protect-main` trên `main` (Settings → Rules → Rulesets, **không** bypass): cấm xoá, cấm force push,
   lịch sử tuyến tính, bắt PR (chỉ squash), bắt 9 status check của `ci.yml`: `gitleaks` · `dotnet (format, build, test)` ·
   `frontend (lint, build)` · `terraform (fmt, validate)` · `terraform plan (infra/app)` · `azure login (OIDC)` ·
   `docker build + trivy (be)` · `docker build + trivy (fe)` · `sast + iac (semgrep, trivy config)`. Bật "Automatically delete head branches".

## 3. Biến của `infra/app`

Chép `infra/app/terraform.tfvars.example` thành `infra/app/terraform.tfvars` (gitignored) rồi điền:

| Biến | Bắt buộc | Ý nghĩa | Lấy ở đâu |
|---|---|---|---|
| `allowed_ips` | **có** | map tên luật → CIDR IPv4 được vào app (M6). Rỗng = khoá cả chính mình | `curl -4 -s https://ifconfig.me`, **tắt VPN/WARP** trước khi đo, đo vài lần (`known-issues.md` #11, #19) |
| `secrets_writer_object_id` | **có nếu bạn không phải tác giả** | người được cấp Key Vault Secrets Officer để Terraform ghi secret | `az ad signed-in-user show --query id -o tsv` |
| `alert_email` | không | người nhận email alert; thiếu thì lần apply sau xoá người nhận | email của bạn; bấm OTP xác minh trong 30 phút |
| `enable_app_insights` | không (mặc định `true`) | dựng App Insights cho trace | — |
| `grant_app_keyvault_access`, `grant_app_acr_pull` | không | chỉ đặt `false` bằng `-var` khi đo chứng minh ngược M5/M1 | — |

Biến môi trường: `ARM_SUBSCRIPTION_ID` (bước 1). Không có secret nào phải đặt tay: mật khẩu MySQL do Terraform sinh
và cất trong Key Vault, app đọc qua Key Vault reference bằng managed identity.

## 4. Hằng ngày

```bash
make plan           # xem trước, không tốn tiền
make up             # dựng môi trường (TỐN TIỀN): apply 3 pha fe → be → toàn bộ, đo thật ~24–25 phút (`evidence/M8.md`)
make outputs        # URL, tên ACR, Key Vault...
make down           # xoá rg-vsf-dev (giữ rg-vsf-bootstrap) — cuối buổi, không để chạy qua đêm
make check-empty    # sau down: rg-vsf-dev phải rỗng/không tồn tại
```

`make up` chạy 3 pha vì firewall MySQL và access restriction của `be` dùng `for_each` trên outbound IP của Web App,
giá trị chỉ biết sau khi Web App tồn tại (`Makefile`, `notes/d8.md`). Sau `make up`, app chạy image giữ chỗ cho tới
lần CD đầu tiên: chạy CD tay một lần (`gh workflow run cd.yml --ref main`) hoặc merge một PR.

⚠️ `make down` gãy nếu trong `rg-vsf-dev` còn resource ngoài Terraform (ví dụ PoC khác, `known-issues.md` #23): xoá
chúng trước.

Code (cùng lệnh CI chạy): `make lint && make test` (be) · `make fe-install && make fe-lint && make fe-test && make fe-build` (fe).
MySQL local cho test đầy đủ: `make test-db`.

## 5. Deploy: PR → CI → merge → CD

1. Nhánh `feat/` · `fix/` · `chore/` · `docs/` từ `main`, sống ≤ 2 ngày. Không push `main` (ruleset chặn: `GH013`).
2. Mở PR, có mục `## AI usage`. `ci.yml` chạy 9 check; `terraform plan` đăng nhập bằng `id-gh-plan` (không ghi được hạ tầng hay state, nhưng đọc được secret DB khi plan — `architecture.md` mục 4).
3. Squash merge → `cd.yml`: build `be` + `fe` (tag = git SHA), quét Trivy lại, sinh SBOM, push ACR, đặt image cho slot
   `staging`, chờ staging trả đúng SHA và `fe` staging gọi được `be` staging, **smoke test nghiệp vụ** (`GET /items`,
   `/stats`, trang `fe`), ZAP baseline (chỉ cảnh báo), swap, kiểm production; sai thì tự swap ngược.
4. Kiểm: `curl https://app-vsf-<s>.azurewebsites.net/version` và `https://fe-vsf-<s>.azurewebsites.net/api/version` = SHA của `main`.

### Các lớp bảo mật trong pipeline (DevSecOps)

| Lớp | Ở đâu | Chặn? | Ngoại lệ được phép |
|---|---|---|---|
| Secret scanning | gitleaks: pre-commit + CI | chặn | — |
| SAST | Semgrep 1.177.0 (`p/csharp`, `p/typescript`, `p/nextjs`, `p/dockerfile`, `p/github-actions`) — CI | chặn ở ERROR | `// nosemgrep: <rule> -- lý do` ngay tại dòng |
| IaC / Dockerfile misconfig | `trivy config` — CI | chặn HIGH/CRITICAL | `.trivyignore` kèm lý do |
| Lỗ hổng image (SCA) | Trivy image — CI **và** CD (quét lại trước push) | chặn HIGH/CRITICAL | `.trivyignore` có `exp:` |
| SBOM | Trivy CycloneDX — CD, artifact 90 ngày | — | — |
| Kiểm hành vi trước swap | smoke `GET /items`, `/stats`, `fe /` trên staging — CD | chặn swap | — |
| DAST | OWASP ZAP baseline thụ động trên staging — CD | **chỉ cảnh báo** | — |
| Drift hạ tầng | `drift.yml`: `plan -refresh-only` hằng ngày 08:17 VN | đỏ workflow | tag image do CD quản lý |
| Cập nhật dependency | Dependabot hằng tuần (NuGet, npm, Actions) | PR qua đủ check | — |
| Danh tính | OIDC + federated credential, không secret; 4 environment chỉ nhận `main`; ruleset 0 bypass | — | — |

Rollback tay: [`docs/rollback.md`](docs/rollback.md). Agent đọc sự cố (chỉ đọc): `gh workflow run agent-triage.yml --ref main -f mode=triage`.

## 6. Teardown hoàn toàn

Theo thứ tự. Bước 3 trở đi **không đảo ngược được**.

1. Xoá resource ngoài Terraform trong `rg-vsf-dev` nếu có (PoC, #23), rồi `make down` → `make check-empty`.
2. Key Vault: provider tự purge secret khi destroy và vault tắt purge protection, nên tên dùng lại được ngay. Kiểm:
   `az keyvault list-deleted --query "[].name" -o tsv` (rỗng, hoặc `az keyvault purge -n <tên>`).
3. ⚠️ `terraform -chdir=infra/bootstrap destroy`: xoá storage chứa **state của `infra/app`** và 3 danh tính, kéo theo mọi
   federated credential. Chỉ làm **sau** bước 1, nếu không `infra/app` sẽ thành resource mồ côi không còn state.
4. GitHub: `gh variable delete` 5 biến ở mục 2, xoá 4 environment (`gh api -X DELETE repos/<owner>/<repo>/environments/<tên>`).
5. Custom role `vsf-gh-plan-web-config-reader`, `vsf-agent-alert-reader` nằm trong state `infra/app` nên đi theo bước 1.

## 7. Khi có sự cố

- Alert bắn: [`runbook.md`](runbook.md) (triệu chứng → xác nhận bằng KQL → xử lý → rollback → escalate).
- Lỗi đã gặp và cách xử lý (429 khi tạo plan, RBAC lan truyền chậm, Key Vault reference, whitelist runner, cổng Trivy…):
  [`known-issues.md`](known-issues.md).

## Luật làm việc

- Mọi PR có mục `## AI usage`. Thao tác tốn tiền (`apply`, `destroy`, `az … create`, test tải, swap) xác nhận trước.
- Autoscale tối đa 2 instance. Secret chỉ sống trong Key Vault. Không đưa dữ liệu công ty vào repo.
- Chi tiết: [`CLAUDE.md`](CLAUDE.md).

## Cấu trúc repo

| Đường dẫn | Là gì |
|---|---|
| `app/be/` · `app/be.Tests/` | Backend .NET 10 + Dockerfile (chiseled) + test xUnit |
| `app/fe/` | Frontend Next.js + Dockerfile (alpine) + test `node:test` |
| `infra/bootstrap/` · `infra/app/` | Terraform: state + danh tính GitHub · môi trường app |
| `.github/workflows/` · `.github/dependabot.yml` | `ci.yml` · `cd.yml` · `drift.yml` · `agent-triage.yml` · `m6-check.yml` · Dependabot |
| `scripts/` | Đo/kiểm: `m2-poll.sh` (M2), `load.sh` + `d19-watch.sh` (M7), `boom.sh` (alert), `agent-*.sh`, `install-hooks.sh` |
| `evidence/` | Bằng chứng M1–M11 + agent; `raw/` log thô; quy ước ảnh: `evidence/screenshots-convention.md` |
| `docs/plans/active/` | Plan đang chạy: checklist, quyết định, câu hỏi cho mentor |

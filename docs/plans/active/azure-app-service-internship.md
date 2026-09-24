# Azure App Service + CI/CD + Monitoring — kế hoạch 5 tuần

**Status:** active
**Opened:** 2026-09-15
**Goal:** Một repo mà người thứ ba `terraform apply` + merge vào `main` là ra app chạy trên App Service, đủ bằng chứng M1–M11 trong `evidence/`, demo live D25.

## Tiến độ — cập nhật 2026-09-24 (hết D16 · D17 đã có kế hoạch)

**D1–D14 xong. D15 HOÃN** (cần repo của intern khác — xem mục D15). Azure **đang tắt**
(chỉ còn `rg-vsf-bootstrap`).
**D16 XONG — M10 ĐẠT.** Nhật ký: `notes/d16.md` · bằng chứng: `evidence/M10.md`.
Kế hoạch gốc `notes/d16-prep.md` có một chỗ **kê sai thuốc** (mục "vấp #1": cả hai cách nó đề
xuất đều tạo `Cycle:` trong Terraform) — cách chữa thật ở `notes/d16.md`.

Một lần chạy end-to-end thật: merge PR #43 → CD tự chạy đủ 3 job → `/version` của **cả hai**
service đổi sang đúng SHA `e6658dc1…`, không một thao tác tay. Môi trường suffix `gdiz89`,
`make up` nay **3 pha**, 35 resource.

**Đi kèm:** `fe` có `/api/version` (M2 ở D18 sẽ cần) · M6 đo lại đủ **8 bề mặt** (4 be + 4 fe)
· `make up` phát hiện `description` của `ip_restriction` giới hạn **64 byte**.

**Rà lại CI/CD sau D16 (2026-09-24, chỉ đọc):** lành, không lỗ mới — 8 job ↔ 8 required check
khớp 1:1, 0 `continue-on-error`, 2 environment khoá `main`, 6 federated credential, actionlint 0
lỗi, hợp đồng CI chạy lại ở máy xanh; 5 run CD gần nhất đủ 3 hành vi (bỏ qua khi tắt · deploy đủ ·
nhánh khác chết ở `azure/login`). Chi tiết: `notes/d16.md` mục cuối.

**Bài tiếp: D17 — kế hoạch làm tay từng bước ở `notes/d17-prep.md`** (4 quyết định A–D cần chốt
trước khi viết code). D17 phải xong trước D18, nếu không phép đo M2 không có giá trị.

| Mốc | Trạng thái | Bằng chứng |
|---|---|---|
| M1 — ACR pull bằng MI | ĐẠT (D11) | `evidence/M1.md` |
| M3 — app ↔ MySQL qua TLS | ĐẠT (D12) | `evidence/M3.md` — *thiếu 1 ảnh Log stream* |
| M4 — Key Vault reference | ĐẠT (D12) | `evidence/M4.md` — *thiếu ảnh Portal* |
| M5 — app gãy khi mất quyền | ĐẠT (D12) | `evidence/M5.md` — *ảnh: đề xuất bỏ* |
| M6 — IP whitelist 4 bề mặt | ĐẠT (D13) | `evidence/M6.md` — *thiếu 3 ảnh Portal* |
| M8 — Terraform toàn bộ hạ tầng | ĐẠT lần 1 (D10) | `evidence/M8.md` — *cần lần 2 ở D15* |
| M9 — CI chặn được cái sai | ĐẠT (D14) | `evidence/M9.md` |
| M10 — CD deploy từ `main` | **ĐẠT (D16)** | `evidence/M10.md` — đủ, kể cả lớp 3 (run `35925778364`) |
| M2, M7, M11 | chưa tới lịch | D18–D22 |

**Còn nợ, không chặn D17:**
- **D15** — hoãn tới khi có repo của intern kia. `notes/d15-prep.md` giữ nguyên giá trị.
- **6 ảnh Portal** — `notes/screenshot-debt.md`. **Cửa sổ D16 không chụp được** → dời sang
  cửa sổ `make up` của D17 (`notes/d17-prep.md` Pha D).
- **Ba việc vặt, không tốn tiền, chen được bất cứ lúc nào:** chuyển `docs/docs_app/architecture.md`
  về **gốc repo** (`topic.md` mục deliverables đòi `architecture.md` ở đó) · test cho `app/fe`
  (`known-issues.md` #16 — D17 quyết định B có thể mở màn) · dựng lại state `infra/bootstrap`
  bằng `terraform import` (#17, **nên làm trước M8 lần 2**).
**Sổ lỗi:** `ai-failure-log.md` 30 case (đề cần 6–8) · `known-issues.md` 17 mục.

## Authority

- Yêu cầu, lịch, deliverables: `topic.md` (mục 2, 4, 6, 7, 8; thay `a.md` cũ, đã xoá) + mục 9 bổ sung Sprint 1–3.
- **Brief bổ sung 2026-09-21** (Sprint 1–3, đã ghi vào `topic.md` mục 9; **cập nhật cho topic.md, không thay thế**): thêm yêu cầu **distributed tracing**, **truy vết alert → log/request**, tài liệu deploy/vận hành/**rollback**, **báo cáo kết quả kiểm thử**. Xem mục "Bổ sung theo brief" bên dưới.
- Luật làm việc của project: `CLAUDE.md`.
- **Chưa định nghĩa (phải hỏi mentor, chặn bước liên quan):**
  - Q1. M11 "không enable App Insights" vs `/boom` "Alert + App Insights" vs lịch D20 vs brief mới đòi distributed tracing → được bật App Insights (workspace-based) làm backend trace không? Nếu không: OTel → Jaeger/Tempo (tốn hạ tầng) hoặc chỉ log `trace_id`. **Mặc định làm theo hướng (a) workspace-based App Insights, đánh dấu tạm** đến khi mentor trả lời. (chặn D20)
  - ~~Q2. Repo public hay private? GitHub Free không có branch protection cho private.~~ **Đã trả lời 2026-09-23 bằng quan sát:** repo là `PRIVATE` (`gh repo view`) mà ruleset `protect-main` vẫn `enforcement: active` và D14 đã chứng minh nó **chặn merge thật** (6 PR đỏ đều `mergeable_state = blocked`, `evidence/M9.md`). Tiền đề của câu hỏi sai: **ruleset** khác branch protection cũ và có hiệu lực trên private repo Free.
  - Q3. "5xx rate" là count hay tỷ lệ %? (chặn D22)
  - ~~Q4. Trivy "không còn CVE" có cho `--ignore-unfixed` không?~~ **Đã chốt 2026-09-23 bằng số đo thật (D14): KHÔNG** — cổng `CRITICAL,HIGH` không `--ignore-unfixed`, vì cả hai image đo ra 0 ở mức đó. Chi tiết ở mục Decisions.
  - ~~Q6. App registration cho OIDC?~~ **Đã trả lời 2026-09-15 (az cli):** tenant `allowedToCreateApps=false` → dùng user-assigned MI + federated credential.
  - ~~Q7. ABAC condition trên Owner?~~ **Đã kiểm 2026-09-15 (az cli):** 2 assignment Owner ở scope subscription, `condition = null`. Banner Portal không phản ánh giới hạn trên assignment của mình; nếu gán role vẫn bị chặn thì hỏi mentor về policy cấp trên.
  - ~~Q8. AI-OFF gắn với tuần 1 theo lịch (trước 23/09) hay theo bài D1–D6?~~ **Hết hiệu lực 2026-09-23:** hôm nay đã là 23/09, tuần 1 kết thúc, D7–D14 đã làm xong với AI theo đúng luật `CLAUDE.md` (mỗi PR có mục `## AI usage`). Không còn gì để quyết.
  - Q5. Subscription Free Trial hết hạn **2026-10-15 (= D23)** → mentor cấp sub khác hay tự upgrade Pay-As-You-Go? (chặn D22)

## Mốc cố định

Không ấn định ngày/thời lượng cho từng bài — tiến độ linh hoạt, chỉ giữ thứ tự bài (`docs/guides/README.md`, cột "Cần xong trước").

| Mốc | Do ai quyết | Ghi chú |
|---|---|---|
| GATE D10 | mentor | destroy → apply + giải thích state/lock/dependency |
| Cross-review lần 1, lần 2 | mentor | cần bạn intern kia sẵn sàng |
| AI-OFF | đề bài: tuần 1 theo lịch, bật từ D7 | Q8 |
| Hạn credit Free Trial | Azure: **2026-10-15** | Q5 — phải xong phần cần Azure trước mốc này hoặc có subscription khác |
| Demo | mentor | |

---

## Tuần 1 — D1–D5 · Nền tảng · **AI-OFF** (chỉ hỏi khái niệm)

Mục tiêu: tự tay làm được mọi thứ mà tuần 2–4 sẽ tự động hoá. Không hiểu tay thì không đọc được Terraform.

### D1 — Azure 101, RBAC, chi phí
- [x] Hiểu và tự vẽ được cây: Tenant → Management group → Subscription → Resource group → Resource — *proof: sơ đồ tay trong `notes/d1.md`*
- [x] Phân biệt control plane (ARM, RBAC) và data plane (Key Vault secrets, blob) — *proof: giải thích bằng lời được với mentor*
- [x] RBAC: role definition · assignment · scope; Owner/Contributor/Reader; `AcrPull`, `Key Vault Secrets User` — *proof: ghi chú*
- [x] Hiểu Managed Identity: system-assigned vs user-assigned, vì sao slot staging cần user-assigned — *proof: ghi chú*
- [x] Mở Cost Management: đặt **Budget $40 + alert 50%/80%/100% + forecast 100%** gửi email — *proof: screenshot budget*
- [x] Kiểm tra Defender for Cloud không bật plan tính phí — *proof: screenshot*
- [x] Chọn region (gần + đủ quota MySQL Flexible + App Service Premium v3) — *proof: ghi Decision*

### D2 — Deploy tay bằng Portal
- [x] Tạo App Service Plan Linux + Web App (code hoặc container mẫu) — *proof: URL trả 200*
- [x] Tạo MySQL Flexible Server Burstable B1ms, bật firewall, kết nối thử từ máy — *proof: screenshot kết nối*
- [x] Tìm trong Portal: outbound IPs, Access restrictions, Deployment slots (thấy vì sao Basic không có slot) — *proof: ghi chú*
- [x] **Xoá sạch resource group cuối ngày** — *proof: RG không còn*

### D3 — Làm lại bằng Azure CLI (tự đọc docs, không nhờ AI viết lệnh)
- [x] Dựng lại đúng D2 bằng CLI, lưu lệnh vào `notes/d3-cli.md` — *proof: file lệnh + URL 200*
- [x] Ghi lại chỗ Portal tự làm ngầm mà CLI phải khai báo rõ — *proof: ghi chú* (đây là thứ Terraform phải khai báo)
- [x] Xoá sạch cuối ngày

### D4 — Viết app
- [x] Chọn ngôn ngữ (gợi ý Go: image distroless dễ đạt 0 CVE; Python/Node khó hơn) — *proof: Decision* → Rust (`app/`), chủ đề node-registry — **đổi sang C#/.NET 2026-09-18, xem Decision cuối file**
- [x] Endpoint `/health` (có kiểm tra DB), `/version` (SHA nhúng lúc build), `/load?seconds=n` (có giới hạn n), `/items` GET/POST 1 bảng, `/boom` — *proof: gọi từng endpoint local* → `evidence/d04/README.md`, 7 kịch bản đạt
- [x] Log JSON 1 dòng/record ra stdout: time, level, method, path, status, duration_ms, message — *proof: output log*
- [x] Config đọc từ biến môi trường; **thiếu hoặc còn nguyên chuỗi `@Microsoft.KeyVault(` thì app thoát lỗi rõ ràng** (phục vụ M5) — *proof: chạy thiếu biến → app fail* → lỗi riêng `UnresolvedKeyVault`
- [x] Xử lý SIGTERM tắt êm; tạo bảng idempotent lúc khởi động — *proof: chạy 2 lần không lỗi*
- [x] Unit test tối thiểu cho handler — *proof: test pass* → `cargo test` 9 pass, clippy + fmt sạch (bản Rust; bản .NET: `dotnet test` 12 pass)

### D5 — Docker local + Cost Analysis
- [x] Dockerfile multi-stage, non-root, build-arg SHA — *proof: `/version` trong container trả SHA* → `scratch` + musl, 5.2 MB
- [x] docker compose app + MySQL local — *proof: `/items` đọc ghi được*
- [x] Trivy scan local, ghi số CVE ban đầu — *proof: output scan* → 0 CRITICAL/HIGH/MEDIUM/LOW thật sự (không cần `--ignore-unfixed`)
- [x] Mở Cost Analysis xem chi phí thật D2–D3 (group by resource/meter) — *proof: screenshot, ghi vào `notes/cost-week1.md`* → thực tế ghi ở `evidence/d05/README.md` (Actual $0.51)
- [x] Tự trả lời được: state là gì, lock là gì, dependency là gì (chuẩn bị GATE) — *proof: ghi chú bằng lời mình*

---

## Tuần 2 — D6–D10 · Repo, CI v1, Terraform · AI bật từ D7 · **GATE D10**

### D6 — Repo + trunk-based + CI v1
- [x] (Q2 phải có câu trả lời) Tạo repo GitHub, push `main` ban đầu — Q2: **private**, GitHub Pro
- [x] Ruleset trên `main`: require PR · require status checks · block force push · chỉ squash merge · auto-delete branch — *proof: screenshot settings* → `push-to-main-rejected.log`
- [x] Cài pre-commit hook gitleaks local — *proof: commit thử secret giả → bị chặn* → `pre-commit-hook-blocked.log`
- [x] Template PR có mục `## AI usage` — *proof: file template* → `.github/pull_request_template.md`
- [x] CI v1 (`ci.yml`, chạy on pull_request): gitleaks + `terraform fmt -check` + `terraform validate` — *proof: 1 PR xanh*
- [x] Tạo sẵn khung `ai-failure-log.md`, `known-issues.md`

### D7 — Terraform nền + remote state
- [x] Bootstrap riêng (ngoài vòng destroy): RG + Storage Account + container cho state; khoá public access — *proof: storage tồn tại; ghi Decision vì sao tách* → `rg-vsf-bootstrap`, `stvsftffxqfgb`
- [x] Backend azurerm, hiểu blob lease = lock — *proof: 2 terminal chạy plan cùng lúc → 1 cái bị lock, lưu log* → `state-lock-error-...png`
- [x] Provider features: purge Key Vault khi destroy; random suffix cho tên duy nhất toàn cầu; tags chung (owner, env, project) — *proof: plan*
- [x] Register provider `Microsoft.Storage` (đang NotRegistered)
- [x] OIDC: **user-assigned MI** `id-gh-plan` / `id-gh-deploy` + federated credential cho GitHub (pull_request / ref main), không client secret — *proof: CI login Azure được* → `oidc-login-success.log`, PR #4

### D8 — Terraform: compute + DB
- [x] App Service Plan (Linux, P0v3 hoặc S1 — Decision kèm giá), Web App + slot `staging` — *proof: plan/apply* · apply + verify 17/09 `evidence/d08/`
- [x] User-assigned MI, gắn cho cả 2 slot — *proof: portal Identity* · `evidence/d08/verify.log`
- [x] MySQL Flexible B1ms + database; firewall `for_each` theo outbound IPs của App Service — *proof: plan* · 20 IP = 20 rule, apply 2 pha `make up`
- [x] Mật khẩu MySQL sinh bằng random_password (hiểu: nó nằm trong state) — *proof: Decision* · `notes/d8.md`

### D9 — Terraform: ACR, Key Vault, Makefile
- [x] ACR Basic, admin disabled; role AcrPull cho MI — *proof: plan* → `infra/app/acr.tf`, `terraform validate` sạch
- [x] Key Vault RBAC mode, secret MySQL password; role Key Vault Secrets User cho MI; role cho chính bạn để Terraform ghi secret — *proof: plan* → `infra/app/keyvault.tf`, 3 role assignment
- [x] Giải quyết vòng lặp image (ACR trống lúc apply lần đầu): placeholder image + `ignore_changes` phần image — *proof: Decision* → `notes/d9.md` Decision #1
- [x] `Makefile`: `up` (apply), `down` (destroy phần tốn tiền, giữ state storage), `plan` — *proof: chạy được* → thêm `outputs`, `check-empty`
- [x] CI: thêm `terraform plan` + upload plan làm artifact — *proof: artifact trong PR* → job `terraform-plan`, `plan.txt`, chưa mở PR để lấy bằng chứng artifact thật
- [x] `make up` thật + verify (az cli) — *proof: `Apply complete! Resources: 20 added`, `plan` lần 2 No changes, production+staging 200, firewall=18=outbound IP, ACR admin disabled, KV RBAC + secret đọc được. Sau 7 lần 429 (26 tiếng) phải đổi region (Central India cho app, giữ Southeast Asia cho MySQL) mới qua được — chi tiết `notes/d9.md`*
- [ ] `make down` + `make check-empty` cuối buổi — *proof: chưa chạy, đang để môi trường sống để verify/demo tiếp*

### D10 — **GATE**
- [x] `terraform destroy` → `apply` sạch, **không thao tác tay**, lưu log thô → `evidence/M8.md` — *proof: log 2 lệnh* — **xong phần chạy (2026-09-21):** `make up` từ rỗng 24 phút 27 giây → bảng kiểm tra 6/6 đạt (200/200, ACR admin `false`, KV RBAC + secret, firewall 18=18, slot staging `UserAssigned`, `plan` No changes) → `make down` 19 phút 21 giây, 36 resource → `rg-vsf-dev` không tồn tại, không có Key Vault đã xoá, state 0. Chạy liền một script, không lỗi, sau 6 lần lỗi trước đó cùng ngày (đường mạng/`yes`/state dở dang). Log: `evidence/raw/m8-apply-2026-09-21.log`, `m8-destroy-2026-09-21.log`. Ảnh Portal sau `make down` đã lưu (đã che email) ở `evidence/d10/screenshots/`. Còn: 7 câu trả lời mentor (việc của bạn) + GATE do mentor quyết. Chi tiết `notes/d10.md`, `evidence/M8.md`.
- [x] Xử lý hết lỗi thời gian lan truyền RBAC / soft-delete nếu gặp, ghi vào `known-issues.md` — *RBAC/soft-delete không gặp; lỗi mạng đã ghi `known-issues.md` mục "Biết là sai" #7*
- [x] Ghi 2 lỗi của Claude vào `ai-failure-log.md` (#9 cách nhập `yes`, #10 `make down` khi state dở dang) — cần bạn xác nhận #10 đúng ý
- [ ] Trả lời mentor bằng lời: state · lock · dependency (implicit vs `depends_on`) · vì sao bootstrap tách riêng · **nói thêm:** không clone mới, thứ tự apply→destroy (`notes/d10-prep.md` mục 5b)
- [ ] Nếu không qua: dừng, thu hẹp scope theo mentor. **Không kéo dài.**

---

## Tuần 3 — D11–D15 · Container, identity, network, CI mở rộng

### D11 — Container deploy qua MI
> Kế hoạch: `notes/d11-prep.md` · nhật ký: `notes/d11.md` · bằng chứng: `evidence/M1.md`. D12 mục 1–2 đã gộp vào cùng thay đổi Terraform (commit `c710815`, nhánh `feat/d11-acr-mi-pull`, **chưa merge `main`** — lần này không qua PR theo quyết định của người dùng).
- [x] Web App **và slot staging** cấu hình pull ACR bằng managed identity (chỉ định client id) — *proof: `acrUseManagedIdentityCreds=true`, `acrUserManagedIdentityID=8a0a974c-a19e-465b-a837-e79ceebafe9a` trên cả 2 slot; ACR `adminUserEnabled=false`; `terraform plan` No changes* → `evidence/M1.md`
- [x] Push image tay lần đầu (tag = git SHA, không `latest`) — *proof: `az acr login` bằng token Entra → `Login Succeeded`; push `vsf-app:c710815` digest `sha256:9dca8e0c…d3315`; staging `/version` = `{"sha":"c710815"}` 200, `/health` = `db: ok`*
- [x] **Swap staging → production** (18:08, người dùng tự chạy — Claude Code chặn lệnh swap 2 lần với lý do `Production Deploy`) — *proof: production `/version` = `{"sha":"c710815"}` 200, `/health` = `{"status":"ok","db":"ok"}` 200, image = ACR, cờ MI `true` + client id đúng sau swap*
- [x] 8 ảnh bằng chứng đã che email → `evidence/d11/screenshots/`
- [x] `terraform plan` sau swap → **No changes** (18:30): production chạy image ACR còn code khai placeholder mà Terraform không đòi đổi → `ignore_changes` đúng
- [ ] Chứng minh ngược (gỡ AcrPull → pull thất bại) — hoãn sang phiên D12 M5 để khỏi bật môi trường thêm lần nữa

### D12 — Key Vault reference + MySQL
- [x] App settings dùng `@Microsoft.KeyVault(...)` + chỉ định identity dùng cho KV reference — *làm sẵn ở D11 (commit `c710815`); proof: trạng thái **Resolved**/UserAssigned cả 2 slot qua `az rest … configreferences`, ảnh `evidence/d11/screenshots/07-env-vars-production.png`, `08-env-vars-staging.png`*
- [x] Kết nối MySQL qua TLS; `/items` đọc ghi trên Azure — *proof: 18:29 trên production sau swap, POST `/items` 201 + GET `/items` 200, bản ghi `d11-check-182949` (lệnh + output đầy đủ ở `notes/d11.md` mục "Chuẩn bị D12"); còn phải chép sang* → `evidence/M3.md`
- [ ] Rà soát: không còn secret plaintext nào trong app settings — *proof: screenshot* → `evidence/M4.md`
- [ ] **Chứng minh ngược M5:** gỡ role MI khỏi KV → refresh reference/restart → app gãy → trả role → app sống lại — *proof: log từng bước* → `evidence/M5.md` (sau đó `apply` lại để không lệch state)

### D13 — IP whitelist ✅ **XONG 2026-09-23** (PR #30 + #31, môi trường suffix `p0hef1`)
- [x] Access restrictions cho prod slot, staging slot và SCM site; default deny — *proof:* `infra/app/app.tf`, `evidence/raw/d13-m6-access-restriction*.json`. **Cần 3 dòng chứ không phải 2:** `ip_restriction_default_action` + `scm_use_main_ip_restriction` + **`scm_ip_restriction_default_action`** — thiếu dòng thứ ba thì Kudu vẫn mở
- [x] curl từ IP cho phép → 200; từ IP ngoài → 403 — *proof:* 4 bề mặt × 3 nguồn IP trong `evidence/M6.md`; runner GitHub `134.33.77.40` 403 cả bốn ([run xanh](https://github.com/lam3082004/devops_vsf/actions/runs/35819073928)), run đỏ trước khi vá giữ lại làm bằng chứng lỗ hổng. Cách test của guide (đổi sang hotspot) **không dùng được** — dùng GitHub Actions + Cloudflare WARP
- [x] Ghi vấn đề: runner GitHub không nằm trong whitelist → Decision "mở tạm luật cho IP runner, xoá ở bước `if: always()`" (mục Decisions, dùng lại ở D17)
- [ ] *(hoãn, không chặn D14)* 3 ảnh Portal của M6 — môi trường đã `make down`; gộp với 3 ảnh còn nợ của D12 vào một phiên có môi trường bật

### D14 — CI mở rộng
> Kế hoạch chi tiết: **`notes/d14-prep.md`**. Nhật ký: `notes/d14.md`. Không tốn tiền, không cần bật Azure.
> Hai thứ chặn đã xử lý xong 2026-09-23: **Q4 đã chốt** bằng số đo thật (mục Decisions), và
> **ruleset đã đọc, không đoán** — tên job chết `rust (fmt, clippy, test)` đã được gỡ từ
> 18/09, nhưng phát hiện thứ khác: chỉ **4/6** job là required check.
- [x] Job lint + unit test — **đã có sẵn** (`dotnet`, `frontend`)
- [x] Docker build (không push) — `docker build + trivy (be)` và `(fe)`, build rồi quét trong cùng job
- [x] Trivy scan image, fail khi có CVE (Q4: `CRITICAL,HIGH`, không `--ignore-unfixed`) → **0 CVE cả hai image** — *proof: `evidence/raw/d14-trivy-*-2026-09-23.txt`*
- [x] `app/fe/Dockerfile` viết mới (chưa từng tồn tại) — không có nó thì không quét Trivy cho `fe` được
- [x] Ruleset `protect-main`: đủ **8** required check (trước đó chỉ 4 — `frontend` và `azure login` không được cưỡng chế, một lỗ M9 thật)
- [x] **Bằng chứng đỏ:** 6 PR cố tình sai, tất cả `mergeable_state = blocked`; `gh pr merge` khi đỏ bị GitHub từ chối; 1 PR xanh đối chứng merge được — *proof: `evidence/M9.md`*
- [x] Kiểm chứng secret giả **không** nằm trên `main` (3 cách độc lập)

**D14 ĐẠT.** `ai-failure-log.md` thêm #25–#27, `known-issues.md` thêm #12–#13.

### D15 — Cross-review lần 1 + dọn — **HOÃN** (quyết định 2026-09-23)
> **Hoãn tới khi có repo của intern kia.** 2/4 ô "Xong khi" phụ thuộc người khác nên không
> tự làm hết được; nhảy thẳng sang D16 để không đứng chờ. `notes/d15-prep.md` **giữ nguyên
> giá trị**, quay lại là làm tiếp được ngay. Việc duy nhất của D15 không cần ai mà lại cần
> môi trường bật — **M8 lần 2** — cân nhắc làm ghép vào cửa sổ `make up` của D16.
>
> Kế hoạch chi tiết: **`notes/d15-prep.md`**. **Chặn: cần repo của bạn intern kia** — 2/4 ô
> phụ thuộc người khác, xin link trước rồi làm song song 3 việc không cần ai.
> **Tốn tiền đúng một bước:** `make down` → `make up` cho M8 lần 2 (~45 phút) — gộp luôn
> 6 ảnh Portal còn nợ vào cửa sổ đó, đừng bật môi trường riêng.
- [ ] Review repo bạn kia → `review-<tên>.md` (theo REVIEW bar: đúng, bảo mật, chứng minh được) — *cần link repo*
- [ ] Nhận review, sửa qua PR riêng, tham chiếu số phát hiện — *cần bạn kia*
- [ ] Tự review repo mình trước bằng chính checklist của guide (3 điểm ⚠️ đã biết, xem prep)
- [ ] Cập nhật `README.md` bản nháp (prereq, biến cần set, up/down, teardown)
- [ ] `destroy` → `apply` lại lần 2 sau khi thêm ACR/KV/whitelist — *proof: log* (cập nhật M8)
- [ ] **6 ảnh Portal còn nợ** (M6 ×3, D12 ×3) — `notes/screenshot-debt.md`. D16 không kịp chụp → **dời sang cửa sổ `make up` của D17** (`notes/d17-prep.md` Pha D)

---

## Tuần 4 — D16–D20 · CD, zero-downtime, autoscale, chi phí

### D16 — CD pipeline
> Nhật ký: **`notes/d16.md`** · kế hoạch gốc `notes/d16-prep.md`. **Tốn tiền** (phải `make up`).
> Quyết định 2026-09-23: **có cả `fe`** · trigger **tự động** theo push `main` ·
> ~~bật duyệt tay trước swap~~ → **không làm được**, GitHub chặn required reviewer với repo
> private (`known-issues.md` #14). CD chạy tự động hoàn toàn, khớp tiêu chí "Xong khi" của guide.
- [x] **Web App `fe` + slot** trong Terraform — `infra/app/app-fe.tf`, `WEBSITES_PORT=3000`, `API_BASE_URL` trỏ `be`, **đủ 3 dòng** `ip_restriction*` cho cả site lẫn slot
- [x] Allow outbound IP của App Service vào `ip_restriction` của `be` — `local.be_ip_rules`; phải cắt cạnh `fe`→`be` bằng `local.be_hostname` để không `Cycle:`, kéo theo `make up` **2 pha → 3 pha**
- [x] Quyền `id-gh-deploy`: `AcrPush` (ACR) + `Website Contributor` (RG) + **`Reader` (RG)** — `AcrPush` không cấp `registries/read` nên thiếu `Reader` là `az acr login` 403
- [x] Bốn federated credential dạng `environment:` — job có `environment` đổi subject OIDC sang `repo:O/R:environment:<tên>`, thiếu là `azure/login` fail *(kế hoạch gốc không nêu)*
- [x] Hai GitHub environment `staging-deploy` / `production`, cả hai giới hạn nhánh `main` — **không** có reviewer, xem trên
- [x] `cd.yml` 3 job: `preflight` (ngoài environment, bỏ qua xanh khi Azure tắt) → `build-deploy-staging` → `swap`
- [x] Deploy chỉ từ `main`, chứng minh đủ **3 lớp** (trigger · deployment branch rule · OIDC subject) — cấu hình kiểm bằng `gh api`; lớp 3 đo bằng run thật `35925778364` (`AADSTS700213`)
- [x] Chạy end-to-end → `/version` production đổi SHA trên **cả hai** service → `evidence/M10.md`
- [x] `evidence/M6.md` — `fe` thêm 4 bề mặt (tổng **8**), đã **đo thật**: 8/8 trả 403 từ IP ngoài
- [x] `fe` có `/api/version` — trước D16 không có route nào trả SHA nên không kiểm được service này

### D17 — Swap an toàn
> Kế hoạch làm tay từng bước: **`notes/d17-prep.md`** (Pha A code lúc Azure tắt → B `make up` →
> C 4 tình huống → D ghi chép → E `make down`). Nhật ký: `notes/d17.md`. **Tốn tiền** từ Pha B.
> Chốt trước: A health path của `fe` · B cách chứng minh `fe`-staging gọi `be`-staging · C thử
> rollback thật · D start time limit.
- [ ] Health check path + swap warm-up path (`be` `/health`, `fe` theo quyết định A) + warm-up statuses `200`, bằng Terraform cho cả 4 khối site/slot — *proof: `az webapp config show` + `appsettings list` cả 4 bề mặt*
- [ ] `API_BASE_URL` slot-sticky, `fe` staging trỏ `be` staging (đóng `known-issues.md` #15) — *proof: `slotSetting=true`, `terraform plan` sau swap No changes*
- [ ] Bỏ `sleep 75`; job `swap` tự poll staging đúng SHA + health 200, dùng luật IP tạm cho runner (Decision D13) — *proof: run log*
- [ ] Kiểm production sau swap, lỗi thì **swap ngược** trong cùng run — *proof: run log + activity log 2 swap/app*
- [ ] Luật tạm luôn được gỡ (`if: always()`) — *proof: `access-restriction show` rỗng tên `cd-*`, `terraform plan` No changes, `m6-check` 403 ×8*
- [ ] 3 tình huống lỗi của guide có run link (không khởi động · `/health` 503 · luật tạm) — *proof: `notes/d17.md`, `evidence/M10.md` mục D17*

### D18 — Bằng chứng zero-downtime
- [ ] Script poll `/version` mỗi giây, ghi timestamp · HTTP code · version — *proof: script trong repo*
- [ ] Chạy script trong lúc merge → CD → swap; log thô: 0 non-200, version A→B — *proof: log* → `evidence/M2.md`
- [ ] Nếu có non-200: tìm nguyên nhân (warm-up, start time, SIGTERM), sửa, chạy lại

### D19 — Autoscale + right sizing
- [ ] Autoscale setting: min 1, **max 2**, scale out CPU > ~70% trong 5 phút, scale in CPU < ~30% — *proof: plan*
- [ ] Test tải ngắn bằng `/load` (vài phút) → thấy 1→2→1 instance — *proof: screenshot metric instance count + run history*
- [ ] Right sizing: xem CPU/memory thực tế, quyết định tier — *proof: Decision*

### D20 — Cost report + App Insights (theo Q1) + tracing
- [ ] App: thêm OpenTelemetry (ASP.NET Core + MySqlConnector), sampling 100% (lưu lượng thấp) — *proof: PR có `## AI usage`; `/items` sinh trace có span DB*
- [ ] Log JSON thêm `trace_id`/`span_id` (lấy từ `Activity.Current`) — *proof: 1 dòng log khớp trace-id trong response header `traceparent`*
- [ ] Không đưa connection string App Insights plaintext: lưu Key Vault, tham chiếu `@Microsoft.KeyVault(...)` — *proof: app settings*
- [ ] `cost-report.md` 1 trang: tier + lý do · autoscale rule · 3 biện pháp đã áp dụng · chi phí thật từ Cost Analysis (screenshot) → `evidence/M7.md`
- [ ] App Insights nếu Q1 cho phép: exception từ `/boom` hiện trong Failures — *proof: screenshot*

---

## Tuần 5 — D21–D25 · Logging, alert, drill, demo

### D21 — Logging
- [ ] Log Analytics workspace + diagnostic settings: AppServiceHTTPLogs, ConsoleLogs, PlatformLogs; MySQL logs/metrics — *proof: plan*
- [ ] KQL: parse log JSON, lỗi theo path, p95 latency, request rate — *proof: query + kết quả*
- [ ] Nghiên cứu giải pháp logging: Log Analytics+Workbook vs Managed Grafana vs tự dựng Loki/Grafana (chi phí, vận hành, query) — *proof: mục trong `architecture.md` hoặc `docs/logging.md`*
- [ ] Workbook/dashboard: response time · request rate · failure rate; CPU/memory/HTTP queue; MySQL CPU/connections/storage; panel xem log — *proof: screenshot* → `evidence/M11.md`
- [ ] Giới hạn retention workspace để tiết kiệm
- [ ] Trace về cùng Log Analytics (App Insights workspace-based): xem được `requests`/`dependencies`/`traces` cạnh log — *proof: KQL join theo `operation_Id` = `trace_id`*
- [ ] Dashboard có đủ 5 mảng: metric · log · trace (end-to-end transaction) · alert đang bắn · health — *proof: screenshot*

### D22 — Alert + runbook + trigger thật
- [ ] **Chốt Q5 trước hôm nay** (credit hết hạn D23)
- [ ] Action group email; 3 alert: 5xx (theo Q3) · CPU cao · MySQL active connections — *proof: plan*
- [ ] Trigger thật ≥ 1 alert (`/boom` hoặc `/load`) → email đến — *proof: screenshot email + alert history* → `evidence/M11.md`
- [ ] **Truy vết alert → request:** từ email alert → mở query KQL → lấy `trace_id` → xem end-to-end transaction và log cùng trace — *proof: quay/ảnh từng bước từ 1 alert thật* → `evidence/M11.md`
- [ ] `runbook.md` cho alert nghiêm trọng nhất: triệu chứng · xác nhận (query nào) · xử lý · rollback (swap ngược) · escalate

### D23 — Agent giới hạn quyền + cross-review 2
- [ ] Bài agent giới hạn quyền (theo hướng dẫn mentor) — *proof: theo yêu cầu bài*
- [ ] Cross-review lần 2 → `review-<tên>.md`

### D24 — Incident drill + hoàn thiện
- [ ] Drill: gây sự cố (deploy bản lỗi / cắt quyền KV) → làm theo runbook → rollback — *proof: timeline ghi lại*
- [ ] **Rollback & recovery test:** (1) swap ngược sau bản lỗi, đo thời gian (RTO) · (2) xoá quyền KV rồi khôi phục · (3) `destroy` → `apply` phục hồi từ state · (4) restore MySQL point-in-time thử 1 lần — *proof: log + thời gian từng kịch bản* → `docs/rollback.md`
- [ ] `docs/deploy.md` (dựng từ đầu), `docs/operations.md` (vận hành hằng ngày, alert, dashboard), `docs/troubleshooting.md` (lỗi đã gặp: 429, RBAC lan truyền, KV reference, whitelist runner) — *proof: người thứ ba làm theo được*
- [ ] `test-report.md`: bảng kịch bản kiểm thử (health, zero-downtime, whitelist, autoscale, alert, rollback) · kết quả · link evidence — *proof: file*
- [ ] `destroy` → `apply` lần cuối từ repo sạch theo đúng `README.md` — *proof: log* → `evidence/M8.md`
- [ ] Hoàn thiện `architecture.md` (mermaid, tách luồng traffic và luồng auth), `README.md`, `known-issues.md`, `ai-failure-log.md` đủ 6–8 case
- [ ] Soát `evidence/M1.md`…`M11.md` đủ 11 file, mỗi file có log/screenshot thật

### D25 — Demo 45 phút (live, không slide)
- [ ] Kịch bản demo theo thứ tự: repo → CI chặn secret → merge → CD + poll zero-downtime → whitelist 200/403 → `/items` → xoá quyền KV → `/load` autoscale → `/boom` alert → **alert → trace_id → log/request** → dashboard/KQL → rollback (swap ngược) → cost
- [ ] `make up` trước demo ≥ 30 phút; `make down` sau demo

---

## Bổ sung theo brief (2026-09-21)

| Tiêu chí brief | Nằm ở | Trạng thái |
|---|---|---|
| Deploy ổn định trên Azure | D10–D11, D16–D18 | đang làm |
| Build/deploy tự động | D14, D16–D17 | chưa |
| Thu thập tập trung log · metric · **trace** | D21 (+ D20 tracing) | trace **mới thêm** |
| Dashboard chỉ số vận hành | D21 | chưa |
| Alert lỗi quan trọng | D22 | chưa |
| **Truy vết alert → log/request** | D22 | **mới thêm** |
| Secret & tài nguyên an toàn | D9, D12–D13 | một phần |
| Tài liệu deploy · vận hành · **rollback** · troubleshooting | D24 | **mới thêm** |
| Báo cáo demo & **kết quả kiểm thử** | D24–D25 | **mới thêm** (`test-report.md`) |

## Ứng dụng OpsBoard (ticket lỗi + kanban) — thêm 2026-09-21

Tài liệu: `docs/docs_app/` (brief, prd, wire-frame, api-spec, architecture, database-schema). **Kế hoạch code: `docs/docs_app/plan/`** (be.md 6 PR, fe.md 5 PR). Cấu trúc code: `app/be` (.NET), `app/be.Tests`, `app/fe` (Next.js, đã khởi tạo).
**Không chặn M1–M11**: làm sau GATE D10, chèn giữa D11–D15, đóng khung thời gian.

- [x] Tách `app/` thành `be/` + `fe/`; test chuyển sang `app/be.Tests/`; cập nhật Makefile, `ci.yml`, `docker-compose.yml`, `.gitignore` — *proof: `make test` 12 pass, `make lint` sạch, `fe` lint + build sạch*
- [x] Rà `docs/docs_app/` khớp code hiện có, chốt 16 điểm mâu thuẫn/mù (mã lỗi 503 vs 500, quy tắc field null theo loại response, tên OpsBoard/NodeRegistry, lịch sử ghi mọi trường, `varchar body`, `unassigned=true`, escape `q`, UTC/`DateTimeKind`, `PATCH` vắng mặt vs `null`, cách FE dựng kanban từ 4 lần gọi `/items`…), ghi 3 điểm chưa chốt vào brief.md (R5 cụ thể hơn, ảnh hưởng nếu chọn 1 image, `/boom` chưa ném exception thật); thêm `docs/docs_app/README.md` + `docs/docs_app/local-dev.md` — *proof: đọc chéo, không tự chạy code (chưa có BE/FE thật)*
- [x] Kế hoạch code chi tiết `docs/docs_app/plan/` (README + be.md + fe.md), chốt 5 quyết định kỹ thuật (mô hình lỗi 400/404/409, enum ra JSON, quy tắc null, transaction, test MySQL thật) — *proof: docker build xanh 184MB + `/version` trả SHA thật sau khi đổi tên*
- [x] BE-2 domain Ticket: 3 bảng `tickets/comments/activities`, `GET/POST /items` (lọc, phân trang, `total` sau lọc), xoá sạch domain `Node` — *proof: 62 test pass; chạy thật trên MySQL: schema đúng index+FK, POST ghi kèm activity `created` cùng transaction, `q` escape đúng (tìm `%` ra 1/4 ticket), `status=IN_PROGRESS`/`limit=101`/`unassigned+assignee` đều 400*
- [x] BE-3: `GET /items/{id}`, `PATCH /items/{id}` (phân biệt vắng mặt vs null), `PATCH /items/{id}/status` + state machine + transaction — *proof: 106 test pass; MySQL thật: chuyển trạng thái và `resolved_at` đúng hết, 5 request song song chỉ 1 thắng và đúng 1 dòng activity (TOCTOU); codex gpt-5.6 soi độc lập: không tìm thấy bug*
- [x] BE-4: `GET|POST /items/{id}/comments`, `GET /stats` + chặn `status` trong `PATCH /items/{id}` (400) — *proof: MySQL thật: `by_status` đủ 4 key kể cả khi bằng 0, `avg_resolution_minutes` 100+200 phút → 150, ticket lạ → 404 chứ không 503*
- [x] BE-5: test tích hợp MySQL thật + CI `services: mysql:8.4` + `make test-db` — *proof: `make check` 127 pass/12 skip, `make test-db` 139 pass/0 skip; trỏ `TEST_DB_NAME` sai → đúng 12 test đỏ (chứng minh không false-green)*
- [x] BE-6: `app/be/seed.sql` 18 ticket / 7 bình luận / 31 activity — *proof: nạp vào DB thật, `/stats` ra `open_critical=1`, `avg_resolution_minutes=185`, 4 cột kanban đều có dữ liệu*
- [x] Sửa 2 bug rò rỉ tên field trong message lỗi (`'id'` và `'payload'` thay vì tên field thật) — *proof: 3 trường hợp đều đúng trên app chạy thật*
- [x] FE-1→FE-5: nền BFF + kanban (@dnd-kit) + danh sách/lọc/tạo + chi tiết + thống kê — *proof: HTTP thật với BE + MySQL; số đếm cột khớp `/stats`, lọc `?status=closed` ra đúng 4 dòng, hành trình tạo→kanban→chi tiết→bình luận→đổi trạng thái→thống kê thông suốt; tắt BE thì cả 4 trang hiện banner + nút "Thử lại"*
- [x] Swagger dùng được: `ProducesResponseType` đủ mã cho 9 path, `X-User-Name` khai bắt buộc đúng 4 operation ghi, tắt ở Production — *proof: `/swagger` 200 ở Development, 404 ở Production; `swagger.json` có `409` ở `PATCH status`*
- [x] **Sửa bug chặn:** tên tiếng Việt trong header `X-User-Name` làm hỏng mọi thao tác ghi ("lâm"→400, "hiếu"→fetch ném lỗi). Percent-encode phía gửi, decode ở backend — *proof: curl UTF-8 → 201 vs curl Latin-1 → 400; sau sửa cả 3 dạng tên đều 201, reporter trả về đúng dấu*
- [x] Việt hoá toàn bộ nhãn (trừ "OpsBoard") + seed tiếng Việt có dấu (`SET NAMES utf8mb4`) + nút đổi Sáng/Tối/Theo hệ thống — *proof: HTML không còn nhãn tiếng Anh; giá trị API giữ nguyên (lọc vẫn 4 dòng, key `/stats` không đổi)*
- [x] **4 PR đã merge vào `main`**: #22 (tài liệu/công cụ) · #28 (BE domain + Swagger) · #24 (test tích hợp) · #25 (FE + 2 bản sửa) — *proof: CI xanh đủ 6 job mỗi PR; `dotnet` 2m2s vì test MySQL thật chạy*
- [x] FE: màn hình theo `wire-frame.md` (kanban, danh sách, tạo, chi tiết, thống kê) — *proof: như FE-1→FE-5 ở trên, PR #25*
- [x] CI cho `fe` (job `frontend`: `npm ci` + lint + `next build`) — *proof: YAML hợp lệ 6 job, `npm ci` + lint xanh local*
- [x] Đổi tên kỹ thuật `NodeRegistry` → **OpsBoard** (csproj, namespace, assembly, Dockerfile, Makefile, ci.yml, `DB_NAME` local) — *proof: `make test` 12 pass, `make lint` sạch sau khi đổi*
- [x] Dockerfile cho `fe` + Trivy scan image `fe`, CD hai service, Terraform web app thứ hai + access restriction — *proof: Dockerfile + Trivy ở D14 (PR #32, `evidence/M9.md`); Web App `fe` + CD hai service ở D16 (PR #42–#44, `evidence/M10.md`)*
- [ ] `TriageProvider` (bản luật) — Jev thật để Stretch, cần duyệt

~~Q10~~ **đã chốt 2026-09-21: hai service** (`fe` + `be`, hai Web App trên cùng một App Service Plan).

## Stretch (chỉ làm khi M1–M11 xong)
- [ ] S1 Trivy fail khi CVE critical (gần như có sẵn từ D14)
- [ ] S2 MI → MySQL bằng Entra auth (cần quyền Graph tenant; tenant vinuni có thể không cho)
- [ ] S3 Private Endpoint + jump VM

## Thói quen hằng ngày
- Sáng `make up`, chiều `make down`; không để gì chạy qua đêm (App Service Plan tính tiền kể cả khi app Stop).
- Kẹt 45 phút → hỏi. Mỗi lần AI sai → 1 dòng `ai-failure-log.md`.
- Cuối ngày cập nhật mục Recovery + Validation bên dưới.

## Decisions
- 2026-09-15 — Region Southeast Asia: MySQL B1ms ($17.94/tháng) và App Service P0V3 ($66.80/tháng) đều khả dụng; gần VN. Chi tiết `notes/d1.md`.
- 2026-09-15 — Dùng user-assigned MI chung cho 2 slot thay vì system-assigned, vì system identity không đi theo code khi swap.
- 2026-09-15 — Budget `budget-intern` hiện **$50/tháng** (az cli; notes D1 lúc tạo ghi $40 — đã được đổi sau), alert 50/80/100% actual + 100% forecasted, không action group.
- 2026-09-15 — OIDC dùng user-assigned managed identity + federated credential (tenant cấm user tạo app registration).
- 2026-09-17 — D8: firewall MySQL `for_each` trên possible outbound IPs xử lý bằng **apply 2 pha trong `make up`** (pha 1 `-target` Web App chỉ khi state chưa có nó); loại tách 2 root module (thêm state, phức tạp vĩnh viễn) và NAT Gateway (tốn tiền theo giờ). Chi tiết `notes/d8.md`.
- 2026-09-17 — D8: MySQL **8.4** (không phải 8.0) — trùng Portal D2 và docker-compose local; plan **P0v3** (0.0915 USD/giờ < S1 0.095, có slot + autoscale).
- 2026-09-18 — D9: role `Key Vault Secrets Officer`/`Secrets User` tách theo 3 principal riêng (least privilege); tra `id-gh-plan` bằng `data` source (tên + RG `rg-vsf-bootstrap`) thay vì `terraform_remote_state`, giữ đúng quyết định D7 tách state; `purge_protection_enabled = false` trên Key Vault để D10 destroy→apply lại cùng tên; job CI `terraform-plan` soi `terraform state list` trước khi plan để tránh lỗi `for_each` khi môi trường đang tắt (giống logic 2 pha của `make up`). Chi tiết `notes/d9.md`.
- 2026-09-20 — **Đổi region**: `var.location` (App Service Plan, Web App, ACR, Key Vault, identity) từ Southeast Asia sang **Central India** — subscription bị Azure throttle riêng cho tạo App Service Plan ở Southeast Asia (7 lần thử/26 tiếng, xác nhận bằng `az cli` gọi thẳng, loại trừ nguyên nhân do Terraform). MySQL vẫn giữ **Southeast Asia** qua `var.db_location` riêng — subscription không có quyền tạo MySQL Flexible ở Central India (`ProvisionNotSupportedForRegion`). Đè lên quyết định region gốc ở `notes/d1.md`. Đánh đổi: 2 vùng khác nhau → thêm latency, chấp nhận được cho môi trường học. Chi tiết đầy đủ: `notes/d9.md`.
- 2026-09-18 — Đổi app từ Rust sang **C#/.NET 10** (ASP.NET Core MVC, kiến trúc Controller → Service → Repository, DI qua constructor) + MySqlConnector, giữ nguyên logic/endpoint/log; nhánh `feat/dotnet-rewrite`. Image runtime **không đạt lại 0 CVE tuyệt đối** như bản Rust (musl+scratch) — chọn `aspnet:10.0-noble-chiseled` framework-dependent thay vì Native AOT (đổi kiến trúc JSON quá nhiều so với lợi ích), cần đo lại bằng Trivy. Chi tiết: `notes/lang-migration-dotnet.md`.

- 2026-09-21 — Ứng dụng đổi sang **OpsBoard** (ticket lỗi + kanban cho team vận hành): backend .NET giữ nguyên stack, thêm frontend Next.js ở `app/fe`; cấu trúc `app/be` + `app/be.Tests` + `app/fe`. Số service chờ Q10. Chi tiết `docs/docs_app/architecture.md`.
- 2026-09-21 — Chốt các hợp đồng còn mâu thuẫn/mù trong `docs/docs_app/` trước khi viết code BE/FE: lỗi không lường trước trả **503 `database_unavailable`** (không phải `500 internal`, khớp `DatabaseExceptionFilter`); `ErrorResponse` bỏ field null (giữ nguyên), còn `Ticket`/`Comment`/`Activity`/`/stats` luôn trả đủ field kể cả `null`; tên kỹ thuật `NodeRegistry` giữ nguyên, `OpsBoard` là tên sản phẩm; lịch sử ghi cho mọi trường đổi (7 action); kanban lấy dữ liệu bằng 4 lần gọi `GET /items?status=…&limit=20`, không thêm endpoint; `PATCH` phân biệt field vắng mặt (không đổi) và field `null` (xoá) qua `JsonElement?`; thêm `unassigned=true` cho `/items`; `q` escape `%`/`_`/`\`, tối đa 100 ký tự; thời gian UTC + `DateTimeKind.Utc` khi map từ MySQL; `X-Trace-Id` dùng `Activity.Current` sẵn có, không cần đợi OpenTelemetry (D20). Chi tiết từng điểm: `docs/docs_app/api-spec.md`, `database-schema.md`, `prd.md`, `brief.md`.
- 2026-09-21 — **Q10: hai service.** `fe` (Next.js) và `be` (.NET) là hai Web App riêng trên **cùng một** App Service Plan (không thêm plan → không thêm tiền plan). Đổi lấy: trace có chặng `fe → be` thật, đúng yêu cầu distributed tracing; giá phải trả là CD, swap, access restriction và Trivy phải làm cho cả hai.
- 2026-09-21 — **Đổi tên kỹ thuật `NodeRegistry` → `OpsBoard`** (csproj, namespace, assembly `OpsBoard.dll`, Dockerfile ENTRYPOINT, Makefile, `ci.yml`, `DB_NAME` local `nodereg`→`opsboard`). **Không đổi** `var.db_name` trên Azure (vẫn `appdb`, tên chung — đổi sẽ tạo lại database). `notes/`, `evidence/`, `ai-failure-log.md` giữ tên cũ vì là nhật ký lịch sử.
- 2026-09-21 — **R5 chấp nhận, không xử lý:** `be` chỉ chặn theo IP, không xác nhận được request thật sự đến từ `fe`. Lý do: công cụ nội bộ, mạng công ty là biên tin cậy, M6 chỉ yêu cầu chặn theo IP.
- 2026-09-23 — **D13/M6 (SỬA cùng ngày, sau khi đo): `scm_use_main_ip_restriction = true` KHÔNG đủ để khoá Kudu.** Nó chỉ cho SCM dùng lại *danh sách luật* của site chính, không kéo theo hành động mặc định — `scmIpSecurityRestrictionsDefaultAction` vẫn là `Allow`, nên IP không khớp luật nào rơi xuống Allow và vào được Kudu. Đo thật: cùng một IP ngoài whitelist, cùng thời điểm, site chính 403 còn SCM trả **200** với token ARM. Phải khai thêm `scm_ip_restriction_default_action = "Deny"` cho **cả** Web App lẫn slot. Suýt bỏ lọt vì `curl` không xác thực vào Kudu luôn trả 401 dù chặn hay không — guide bảo "401 là đạt" (mục 3.2) và điều đó **sai** cho bài này; phải gọi có token mới phân biệt được. Bằng chứng: `evidence/M6.md`, `evidence/raw/d13-m6-scm-hole-2026-09-23.log`.
- 2026-09-23 — **D13/M6: SCM dùng chung luật với site chính** (`scm_use_main_ip_restriction = true`) trên cả Web App lẫn slot staging, thay vì khai danh sách SCM riêng. Lý do: danh sách SCM để riêng có mặc định `Deny all`, quên khai allow là tự khoá mình khỏi Kudu — D3 đã dính đúng bẫy đó khi cấu hình bằng CLI (`notes/d3-cli.md:34-36`); dùng chung thì sửa IP một chỗ, không lệch giữa hai danh sách. Đánh đổi: không siết SCM chặt hơn site chính được (ví dụ chỉ cho IP nhà vào Kudu nhưng vẫn cho IP mentor xem app) — khi cần thì phải tách, và mọi thay đổi từ đó phải làm hai lần.
- 2026-09-23 — **D13/M6: IP cá nhân không vào repo.** `var.allowed_ips` kiểu `map(string)` (khoá = tên luật, giá trị = CIDR), giá trị thật nằm trong `infra/app/terraform.tfvars` bị `.gitignore` chặn; repo chỉ có `terraform.tfvars.example`. Hệ quả đã biết, không phải drift: job `terraform-plan` của CI chạy **không có** tfvars nên luôn thấy `allowed_ips = {}` → khi môi trường thật đang bật, plan của CI sẽ báo xoá các luật. Chấp nhận (CI chỉ plan, không apply); muốn hết thì phải đẩy IP vào GitHub Variable, tức là đưa IP cá nhân lên repo — không đổi.
- 2026-09-23 — **D13/M6: bằng chứng 403 lấy từ GitHub Actions**, không phải đổi laptop sang hotspot như guide gợi ý — máy làm việc vốn chạy bằng chính hotspot đó nên hai bên chung một IP công khai. Workflow `.github/workflows/m6-check.yml` (`workflow_dispatch`, không secret, không OIDC) gọi 4 bề mặt và đỏ nếu mã HTTP lệch. Azure Cloud Shell làm lần đo thứ hai.
- 2026-09-23 — **D13 → D17: CD mở tạm luật cho IP runner rồi luôn xoá** ở bước dọn `if: always()`. Loại 3 cách kia: "mở dải IP GitHub" là hàng nghìn dải, coi như mở toang và không đạt M6; "chỉ dựa vào warm-up của swap" thì CD không tự kiểm tra được SHA đang chạy; self-hosted runner thì thêm một máy phải vận hành. Rủi ro của cách đã chọn: luật tạm không bị xoá khi job chết giữa chừng → whitelist rách âm thầm, nên bước dọn phải `if: always()` và M6 phải đo lại sau mỗi lần đổi CD. Log của `m6-check.yml` chính là bằng chứng "runner bị 403 nếu không mở tạm".
- 2026-09-23 — **D13 hiện chỉ phủ 4 bề mặt, không phải 8.** Terraform mới có **một** Web App (`be`); Web App `fe` của Q10 chưa tồn tại trong `infra/`. Khi `fe` được dựng (D16) thì `ip_restriction` + `scm_use_main_ip_restriction` phải khai lại cho nó và `evidence/M6.md` phải thêm 4 dòng — nếu không, `fe` mở ra Internet trong khi `be` đã khoá.

- 2026-09-23 — **Q4 CHỐT bằng số đo thật: cổng Trivy = `CRITICAL,HIGH`, KHÔNG `--ignore-unfixed`.** Đo local (trivy 0.74.0, `--scanners vuln`): `be` (`aspnet:10.0-noble-chiseled`) **0 CRITICAL / 0 HIGH**, còn 7 MEDIUM đều ở `libc6` — 6 cái đã có bản vá `2.39-0ubuntu8.9` nhưng image Microsoft published chưa kèm (`docker pull` xác nhận base đang là bản mới nhất), 1 cái chưa có bản vá. `fe` sau khi vá Dockerfile: **0 CVE ở mọi mức**. Vì cả hai đo ra 0 ở mức cổng nên KHÔNG thêm `--ignore-unfixed`: thêm vào lúc này không đổi màu gì mà chỉ làm cổng yếu đi về sau. **Không** đưa MEDIUM/LOW vào cổng — 7 MEDIUM của `be` nằm ở base image không tự vá được, gate mức đó là CI đỏ triền miên vì thứ team không sửa được; vẫn quét và in bảng đầy đủ vào job summary để thấy drift. Cửa thoát khi buộc phải bỏ qua: `.trivyignore` kèm mã CVE + lý do + **ngày xem lại**. Output thô: `evidence/raw/d14-trivy-*-2026-09-23.txt`.
- 2026-09-23 — **D14: `app/fe/Dockerfile` viết mới** (trước đó chưa tồn tại — `output: "standalone"` đã bật sẵn từ D11 nhưng file thì chưa có, nên vế "Trivy phải làm cho cả hai" của Q10 không thực hiện được). Hai quyết định trong đó đều do Trivy ép ra, không phải chọn trước: (1) base `node:24-alpine3.23` chứ không phải `3.22` — bản 3.22 còn openssl `3.5.6-r0` với 2 CVE HIGH đã có bản vá ở `3.5.7`/`3.5.8`; (2) **xoá npm khỏi stage runtime** — 10 CVE (trong đó **1 CRITICAL**, `tar` CVE-2026-59873) đều nằm ở `/usr/local/lib/node_modules/npm`, không cái nào thuộc app, mà runtime chạy `node server.js` thì không dùng npm. Tổng cộng 1 CRITICAL + 13 HIGH → 0, bằng cách **bớt thứ có trong image**, không phải nới chính sách quét. Ngược với phản xạ thường gặp: thấy image đỏ thì đi tìm cờ để tắt, trong khi chỗ đúng để sửa là Dockerfile.
- 2026-09-23 — **D14: `docker-build` và `trivy` gộp một job cho mỗi service** (`docker build + trivy (be)`, `docker build + trivy (fe)`), không tách hai job. Lý do đúng như bẫy guide cảnh báo: image nằm trong docker daemon của runner, job khác không thấy — tách ra thì phải `docker save`/artifact/`docker load` (thêm chỗ để lệch), hoặc tệ hơn là Trivy lặng lẽ kéo một image trùng tên từ Internet về quét và báo xanh cho thứ không phải bản vừa build. Giá phải trả: tên job dài hơn và required checks thành 8 thay vì 7.
- 2026-09-23 — **D15 hoãn, làm D16 trước.** D15 mở đầu bằng *"Cần: bạn intern kia đã có repo"* và 2/4 ô "Xong khi" phụ thuộc người khác, nên đứng chờ là mất buổi. `notes/d15-prep.md` giữ nguyên giá trị, quay lại làm tiếp được ngay. Hệ quả phải nhớ: **M8 lần 2** (destroy → apply sau thay đổi tuần 3) vốn nằm trong D15 và là việc duy nhất của D15 không cần ai — cân nhắc ghép vào cửa sổ `make up` của D16 thay vì để treo. 6 ảnh Portal còn nợ cũng chuyển sang cửa sổ đó.
- 2026-09-23 — **D16 làm cả `fe`, không tách sang buổi khác.** Q10 chốt hai service từ 21/09 nhưng `infra/` tới giờ mới có Web App của `be`; để lệch thêm nữa thì mọi bài sau (D17 swap, D19 autoscale, D21 log) đều phải làm hai lần. Giá phải trả: D16 phồng gần gấp đôi vì thêm một khối Terraform chưa từng apply — Web App + slot + `WEBSITES_PORT = 3000` (khác `be` 8080) + `API_BASE_URL` + **ba** dòng `ip_restriction*` cho cả site lẫn slot. Dùng lại `azurerm_user_assigned_identity.app` (đã có `AcrPull`) và cùng App Service Plan nên không thêm tiền plan.
- 2026-09-23 — **`fe` gọi `be` phải được allow bằng outbound IP của App Service.** `app/fe/src/lib/api.ts:62` gọi `be` từ **phía server**, nên request đi ra Internet rồi vòng lại bằng outbound IP của App Service chứ không đi đường nội bộ — mà `be` từ D13 đang `ip_restriction_default_action = "Deny"`. Không xử lý thì mọi trang của `fe` hỏng, và **triệu chứng trông như lỗi app** (trang trắng, lỗi fetch) chứ không như lỗi mạng. Dùng lại đúng mẫu `infra/app/db.tf:77` (`possible_outbound_ip_address_list`), hai app chung plan nên chung IP. Đánh đổi đã biết và chấp nhận: outbound IP dùng chung cho cả scale unit nên app của khách khác cùng stamp cũng vào được `be` — đúng hạn chế `evidence/M3.md` đã nêu cho firewall MySQL, nay lặp ở tầng HTTP; R5 (Decision 2026-09-21) đã chấp nhận mô hình chặn theo IP. Muốn chặt hơn phải VNet integration + Private Endpoint (S3).
- 2026-09-23 — **`cd.yml` chia 3 job và dùng HAI environment**, thay vì một job một environment. `preflight` nằm **ngoài** environment và soi xem Web App có tồn tại không: repo có kỷ luật `make down` cuối ngày nên phần lớn push vào `main` rơi vào lúc không có gì để deploy, mà environment protection áp ở **cấp job** — để job đầu trong environment thì mọi PR tài liệu đều sinh một yêu cầu duyệt treo. Hai environment vì nút duyệt phải nằm **trước swap**, không phải trước build: `staging-deploy` (chỉ `main`, không reviewer) cho build/push/deploy slot, `production` (chỉ `main`, có reviewer) cho swap. Một environment duy nhất có reviewer sẽ chặn ngay từ bước build, tức bắt bấm duyệt khi image còn chưa tồn tại.
- 2026-09-23 — **Bật required reviewer trước swap, và phải giải trình với M10.** Guide D16 mục "Xong khi" đòi *"merge → production đổi SHA **không thao tác tay**"*, trong khi nút duyệt là đúng một thao tác tay. Chọn bật vì không muốn có gì vào production mà không ai nhìn (guide mục 2 cho phép: *"tuỳ chọn: required reviewers"*). `evidence/M10.md` **phải nói rõ**: build → push ACR → deploy slot staging là hoàn toàn tự động, người chỉ duyệt đúng bước swap cuối. Đường lui nếu người chấm không chấp nhận: tắt reviewer, merge thêm một PR, chụp lần chạy không có bước duyệt — ~10 phút, không phải sửa code.

## Rủi ro đã biết
- Máy làm việc dùng hotspot điện thoại → IP công khai động: ảnh hưởng firewall MySQL, access restriction (D13) và **cách lấy bằng chứng M6** (hotspot + điện thoại đó dùng chung IP → phải mượn mạng khác). Chi tiết: `notes/d2.md`.
- **D13 đo ra cụ thể hơn (2026-09-23):** không phải "IP đổi theo thời gian" mà là **hai IP dùng song song** — CGNAT nhà mạng NAT mỗi kết nối qua một trong hai địa chỉ thoát (70 mẫu `curl -4`, ~50/50, không có cái thứ ba). Mọi whitelist phải khai cả hai, nếu không thì cứ hai request có một cái bị chặn. Cloudflare WARP nếu bật còn làm hỏng phép đo nặng hơn (dải anycast dùng chung + ép đi IPv6) → **tắt WARP trước khi đo IP**. `known-issues.md` #11.

## Recovery
- 2026-09-24 14:50: **Môi trường ĐANG BẬT, suffix `jcip0s`** (`make up` do người dùng chạy). Run CD chạy tay `35971154164` (07:43Z) thành công: production `be` + `fe` = `9d4e160`, `/health` `db: ok`, 4 endpoint 200; hai slot staging giữ placeholder (đúng sau swap). ⚠️ **Whitelist sai:** luật `cong-ty` = `104.30.170.218/32` là IP thoát **Cloudflare WARP** (AS13335), không phải IP nhà mạng — mở app cho người dùng WARP khác và đổi IP bất chợt (nghi là nguyên nhân 403 lúc 11:36). `mentor`/`nha-lam` là IP dải tài liệu `198.51.100.x`/`203.0.113.x`, không dùng được. Việc cần làm: tắt WARP → đo IP thật nhiều lần → sửa `terraform.tfvars` → `terraform apply` (hỏi trước). **Cuối phiên: `make down`.** Swagger trên staging: đề xuất cờ `SWAGGER_ENABLED` slot-sticky, gộp vào D17 Pha A (chưa làm).
- 2026-09-24 (chiều): **Rà lại CI/CD sau D16 + lên kế hoạch D17.** Không tốn tiền, Azure vẫn tắt. Pipeline D16 lành (chi tiết `notes/d16.md` mục cuối); không lỗ mới, 3 lỗ đã ghi sổ (`sleep 75`/không kiểm production sau swap · #15 · #16). Kế hoạch làm tay `notes/d17-prep.md`. **Lưu ý:** checkout chính ở máy đứng ở `b41af2d`, sau 5 commit D16 — `git pull` trước khi đọc, và sửa chưa commit trên file plan ở đó (mục OpsBoard FE) đã được gộp vào bản này. **Bước tiếp:** chốt 4 quyết định A–D trong `notes/d17-prep.md`, rồi Pha A trên nhánh `feat/d17-safe-swap`.
- 2026-09-21 (tối): **BE-1 xong** — `ApiSetup` gom DI/JSON/pipeline (hết 4 khối trùng giữa `Program.cs` và `HttpTests.cs`), `Result<T>` có `ErrorKind` 400/404/409, `JsonStringEnumConverter` snake_case, `EnumNames<T>`, đảo quy tắc null, `TraceIdMiddleware` (+`trace_id` trong log), `UserNameFilter`. **38 test pass** (trước 12). Chạy thật với MySQL: `/health` ok, `X-Trace-Id` có, `traceparent` từ client được giữ nguyên, thiếu `X-User-Name` → 400, body hỏng → `ErrorResponse`. Hai ca AI sai ghi vào `ai-failure-log.md` #12, #13. Cài lại gitleaks + pre-commit hook (`scripts/install-hooks.sh`) và docker compose plugin. Bài tiếp: BE-2 (domain Ticket).
- 2026-09-21 18:35: **D11 XONG. D1–D11 đã đóng, sẵn sàng D12.** Swap 18:08 → production `/version`=`c710815`, `/health` `db: ok`, image ACR, cờ MI + client id đúng sau swap. Lease mồ côi trên `app.tfstate` đã gỡ (người dùng `lease break` sau khi tắt Cloudflare WARP); mạng đo lại **20/20**; `terraform plan` chạy trọn → **No changes** (bằng chứng quyết định cho `ignore_changes`). Tranh thủ lấy luôn **M3 của D12**: POST `/items` 201 + GET `/items` 200 trên production (bản ghi `d11-check-182949`) — chép sang `evidence/M3.md` khi làm D12. 5 commit trên `feat/d11-acr-mi-pull`. **CÒN LẠI: `make down`** (môi trường bật từ ~16:14) và đưa các commit vào `main`.
- 2026-09-21 18:20: **D11 xong về mặt bằng chứng M1; còn 1 việc chặn kỹ thuật.** Swap lúc 18:08 → production `/version` = `c710815`, `/health` `db: ok`, image ACR, cờ MI + client id đúng sau swap (staging nhận lại placeholder — đúng thiết kế). `evidence/M1.md` đủ, chỉ còn ô "chứng minh ngược" chủ ý hoãn sang D12 M5. 9 ảnh + tài liệu đã commit trên `feat/d11-acr-mi-pull` (`c710815`, `1c6c4a2`, `44bb3fd`). **CHẶN:** `terraform plan` lúc 18:12 đứt vì mạng và **không nhả được state lock** → lease `infinite` mồ côi trên `app.tfstate`, metadata rỗng nên `force-unlock` vô dụng; phải `az storage blob lease break` (Claude Code chặn, người dùng chạy). Lease này **chặn cả `make down`**. Môi trường vẫn BẬT từ ~16:14. Mạng lỗi 3 lần liên tiếp 18:10–18:15 — kiểm WARP trước khi destroy. Chi tiết `notes/d11.md`.
- 2026-09-21 17:45: **D11 gần xong — chỉ còn swap.** Terraform (commit `c710815`, nhánh `feat/d11-acr-mi-pull` trong worktree, **chưa vào `main`**) bật pull ACR bằng user-assigned MI + client id, đưa `WEBSITES_PORT` lên 8080, thêm app settings DB + `DB_PASSWORD` Key Vault reference + `key_vault_reference_identity_id` (gộp D12 mục 1–2), thêm `docker_registry_url` vào `ignore_changes`. Môi trường suffix `c2021f` đang **BẬT từ ~16:14** — phải `make down`. Đã đo: cờ MI `true` + client id đúng trên cả 2 slot, `DB_PASSWORD` **Resolved**/UserAssigned cả 2 slot, `plan` No changes, staging `/version`=`c710815` + `/health` `db: ok`. **Production vẫn chạy placeholder, `/version` 404 — chưa swap** (lệnh `az webapp deployment slot swap` bị bộ lọc Claude Code chặn với lý do `Production Deploy`; người dùng tự chạy). Bằng chứng: `evidence/M1.md`, `evidence/d11/screenshots/` (8 ảnh đã che email), `notes/d11.md`. AI sinh sai mới: `ai-failure-log.md` #11 (lệnh `make up` thiếu `cd` vào worktree → apply nhầm code `main`).
- 2026-09-21: tách `app/` → `be/` + `fe/`, khởi tạo Next.js (16.3.5), viết `docs/docs_app/`. Chưa commit. CI chưa có job cho `fe`.
- 2026-09-21: **D10 chốt phần Claude làm được; D11 đã có kế hoạch chi tiết.** Đã ghi `ai-failure-log.md` #9–#10 (tổng 10 case, chọn 8 khi nộp), thêm mục 5b "nói thêm với mentor" vào `notes/d10-prep.md` (không clone mới, apply→destroy, 6 lần lỗi). `~/.bashrc` đã có `DOTNET_ROOT`/`PATH`; nhóm `docker` đã có `tts` nhưng phiên cũ chưa nạp (mở terminal mới). Còn của bạn: 7 câu trả lời mentor + GATE do mentor quyết. **D11:** `notes/d11-prep.md` (3 Decision A/B/C chờ bạn chốt, 7 bước, bước 1 không tốn tiền). Môi trường đang tắt.
- 2026-09-21 14:55: **D10: đủ bằng chứng M8, chờ 7 câu trả lời mentor.** Cặp log sạch + verify + step4 trong `evidence/raw/`, `evidence/M8.md` đã điền, ảnh Portal ở `evidence/d10/screenshots/`. `rg-vsf-dev` không tồn tại, state rỗng, không tốn tiền (kiểm lại 14:50). **Trước D11:** (1) user `tts` chưa thuộc nhóm `docker` → `docker build/push` bị `permission denied` (cần `sudo usermod -aG docker $USER` rồi đăng nhập lại; Claude không có mật khẩu sudo); (2) `/usr/bin/dotnet` chỉ là host, SDK ở `~/.dotnet` nên cần `DOTNET_ROOT=$HOME/.dotnet` và `~/.dotnet` đứng đầu `PATH` (với PATH đó `make check` = 12/12 test pass); (3) commit docs D10 qua PR; (4) làm D12 mục 1–2 trước khi đổi image ở D11. Chi tiết `notes/d10.md`.
- 2026-09-20: **D9 xong hoàn toàn** — sau 7 lần 429 (26 tiếng), chẩn đoán ra throttle riêng Southeast Asia, đổi region (App/ACR/KV → Central India, MySQL giữ Southeast Asia). `make up` thành công: 20 resource (+ 5 pha 1), `plan` lần 2 No changes, verify đủ (200 cả 2 slot, firewall=outbound IP, ACR/KV đúng cấu hình). Bài tiếp: D10 GATE (destroy → apply sạch). Chi tiết `notes/d9.md`.
- 2026-09-18: D9 code xong (ACR, Key Vault, lifecycle image, outputs, Makefile, CI job terraform-plan) — chưa `make up` thật được, Azure trả 429 throttle khi tạo App Service Plan (4 lần thử, hơn 1 tiếng, cùng lỗi). State sạch (chỉ RG + identity + random_string). Xem `known-issues.md` #6, `notes/d9.md`.
- 2026-09-17: **D8 xong** — PR #5: `make up` 2 pha (3 + 24 resource), kiểm chứng đạt (200 cả 2 slot, cùng identity, 20 IP = 20 rule, không 0.0.0.0/IP máy), plan lần 2 No changes, `make down` 29 destroyed, `rg-vsf-dev` đã xoá, bootstrap còn. Bài tiếp: D9 (ACR, Key Vault, Makefile, CI plan).
- 2026-09-15: repo mới chỉ có `a.md`, `CLAUDE.md`, plan này. Chưa có Azure resource nào. Chưa commit.
- Subscription: Azure Free Trial, $200 credit, hết hạn 2026-10-15.
- 2026-09-16: **D3 xong** — dựng lại toàn bộ bằng CLI (RG, MySQL, plan P0V3, web app, 20 firewall rule bằng vòng lặp, access restriction, slot+swap, scale out), 4 thí nghiệm idempotency. Phát hiện chính: chạy lại `az webapp create` **reset `httpsOnly` true→false** không báo lỗi. Đã xoá `rg-d3-cli` 16:07. Chi tiết `notes/d3-cli.md`.
- 2026-09-16: D2 xong — dựng tay Web App P0V3 + MySQL B1ms, chứng minh 403 từ IP lạ, swap có 1 request timeout, đã xoá `rg-d2-manual` (12:05), subscription trống. Chi tiết `notes/d2.md`.
- 2026-09-15: D1 xong (region Southeast Asia, budget $40, Defender 0 plan, RG playground đã xoá). D2 bắt đầu — tiến độ ở `notes/d1.md`, `notes/d2.md`. Sổ khái niệm: https://claude.ai/artifact/DcVdzVVpzjVecMt128tGFM

## Validation
- 2026-09-15 — Kiểm tra kế hoạch bằng Azure CLI 2.90.0 (chỉ đọc, subscription `Azure subscription 1`):
  - Tenant ID `58f82789-6695-4f4a-abdb-357668d55cff` = Tenant Root Group ✅
  - Resources / resource groups: trống ✅
  - Providers Registered: Web, DBforMySQL, ContainerRegistry, KeyVault, ManagedIdentity, OperationalInsights, Insights, CostManagement ✅ · **NotRegistered: Microsoft.Storage (cần cho D7), Microsoft.AlertsManagement (D22)**
  - Role của mình: Owner × 2 ở subscription, không condition ✅ (Q7)
  - Tenant policy `allowedToCreateApps=false` → không tạo app registration (Q6)
  - Defender pricing: mọi plan trả phí `Free`; `FoundationalCspm` và `Discovery` hiện `Standard` (thành phần nền) — xác nhận không có meter Defender trong Cost Analysis ở D5
  - Budget `budget-intern` = 50 USD Monthly
  - SKU Linux khả dụng ở Southeast Asia: B1, S1, P0V3, P0V4 ✅ · MySQL Flexible Burstable `Standard_B1ms` (1 vCore, 2 GB, 640 IOPS) ✅
  - Giá Retail API (SEA, Linux, USD/giờ): B1 0.018 · S1 0.095 · **P0v3 0.0915** · P0v4 0.0949 · P1v3 0.183 · MySQL B1ms 0.026 (+ storage 0.138/GB-tháng) · ACR Basic 0.1666/ngày · Log Analytics 2.99/GB · Key Vault 0.03/10K ops
  - Mọi nhóm lệnh `az` nhắc trong D3 (mysql flexible-server, appservice plan, webapp config access-restriction, webapp deployment slot, webapp config container, identity federated-credential, monitor …) tồn tại; `access-restriction add` có `--scm-site`, `--slot`; `webapp config set` có `--acr-use-identity`, `--acr-identity`
  - Công cụ máy: terraform 1.15.8 ✅, docker 29.2.1 ✅, jq ✅, gh ✅ · **chưa có gitleaks, trivy**
  - Không kiểm được bằng CLI: quota vCPU App Service (API usages trả MethodNotAllowed), `max_connections` B1ms (cần server), gói GitHub (API không trả plan) → Q2 còn mở
- 2026-09-15 — `bash ~/.claude/harness/doctor.sh` → harness healthy (guard 55, format 12).

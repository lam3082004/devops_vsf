# Azure App Service + CI/CD + Monitoring — kế hoạch 5 tuần

**Status:** active
**Opened:** 2026-09-15
**Goal:** Một repo mà người thứ ba `terraform apply` + merge vào `main` là ra app chạy trên App Service, đủ bằng chứng M1–M11 trong `evidence/`, demo live D25.

## Authority

- Yêu cầu, lịch, deliverables: `topic.md` (mục 2, 4, 6, 7, 8; thay `a.md` cũ, đã xoá) + mục 9 bổ sung Sprint 1–3.
- **Brief bổ sung 2026-09-21** (Sprint 1–3, đã ghi vào `topic.md` mục 9; **cập nhật cho topic.md, không thay thế**): thêm yêu cầu **distributed tracing**, **truy vết alert → log/request**, tài liệu deploy/vận hành/**rollback**, **báo cáo kết quả kiểm thử**. Xem mục "Bổ sung theo brief" bên dưới.
- Luật làm việc của project: `CLAUDE.md`.
- **Chưa định nghĩa (phải hỏi mentor, chặn bước liên quan):**
  - Q1. M11 "không enable App Insights" vs `/boom` "Alert + App Insights" vs lịch D20 vs brief mới đòi distributed tracing → được bật App Insights (workspace-based) làm backend trace không? Nếu không: OTel → Jaeger/Tempo (tốn hạ tầng) hoặc chỉ log `trace_id`. **Mặc định làm theo hướng (a) workspace-based App Insights, đánh dấu tạm** đến khi mentor trả lời. (chặn D20)
  - Q2. Repo public hay private? GitHub Free không có branch protection cho private. (chặn D6)
  - Q3. "5xx rate" là count hay tỷ lệ %? (chặn D22)
  - Q4. Trivy "không còn CVE" có cho `--ignore-unfixed` không? (chặn D14)
  - ~~Q6. App registration cho OIDC?~~ **Đã trả lời 2026-09-15 (az cli):** tenant `allowedToCreateApps=false` → dùng user-assigned MI + federated credential.
  - ~~Q7. ABAC condition trên Owner?~~ **Đã kiểm 2026-09-15 (az cli):** 2 assignment Owner ở scope subscription, `condition = null`. Banner Portal không phản ánh giới hạn trên assignment của mình; nếu gán role vẫn bị chặn thì hỏi mentor về policy cấp trên.
  - Q8. AI-OFF gắn với tuần 1 theo lịch (trước 23/09) hay theo bài D1–D6? Làm nhanh hơn lịch thì bài D7+ trước 23/09 có được nhờ AI sinh code không? (ảnh hưởng tốc độ D7–D9)
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
> Kế hoạch chi tiết: **`notes/d14-prep.md`**. Không tốn tiền, không cần bật Azure.
> Hai thứ chặn phải xử lý trước khi viết job: **Q4 chưa chốt** (phải quét thật `app/be`
> và `app/fe` lấy số rồi mới chọn chính sách — D5 đo ảnh Rust, app nay là .NET), và
> **required checks có thể vẫn trỏ tên job đã chết** `rust (fmt, clippy, test)`.
> `ci.yml` hiện có 6 job, thiếu đúng `docker-build` và `trivy`.
- [ ] Job lint + unit test — *proof: PR xanh* — **đã có sẵn** (`dotnet`, `frontend`)
- [ ] Docker build (không push) — *proof: PR cố tình làm Dockerfile hỏng → đỏ*
- [ ] Trivy scan image, fail khi có CVE (theo câu trả lời Q4) → đạt 0 CVE — *proof: output*
- [ ] **Bằng chứng đỏ:** PR cắm secret giả → gitleaks đỏ + nút merge bị khoá; thử merge khi pipeline đỏ → bị chặn — *proof: 2 screenshot* → `evidence/M9.md`

### D15 — Cross-review lần 1 + dọn
- [ ] Review repo bạn kia → `review-<tên>.md` (theo REVIEW bar: đúng, bảo mật, chứng minh được)
- [ ] Nhận review, sửa qua PR
- [ ] Cập nhật `README.md` bản nháp (prereq, biến cần set, up/down)
- [ ] `destroy` → `apply` lại lần 2 sau khi thêm ACR/KV/whitelist — *proof: log* (cập nhật M8)

---

## Tuần 4 — D16–D20 · CD, zero-downtime, autoscale, chi phí

### D16 — CD pipeline
- [ ] `cd.yml` (tách file khỏi CI), trigger push `main`: build (SHA) → push ACR → set image slot staging — *proof: run log*
- [ ] Deploy chỉ từ `main` (environment/OIDC subject giới hạn ref main) — *proof: branch khác không deploy được*

### D17 — Swap an toàn
- [ ] Health check path + swap warm-up path `/health`; xác định setting nào slot-sticky — *proof: Decision*
- [ ] Bước chờ staging trả đúng SHA mới (xử lý whitelist cho runner theo Decision D13, luôn gỡ rule tạm trong bước cleanup) — *proof: run log*
- [ ] Swap staging → production — *proof: run log* → `evidence/M10.md` (1 lần chạy end-to-end từ merge)

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
- [ ] FE-2→FE-5: kanban, danh sách + tạo, chi tiết, thống kê — *proof: chạy local với BE thật*
- [x] FE-1 nền frontend: `types.ts` + `api.ts` (client phía server) + 4 route handler BFF + `NameGate` + layout nav + 4 trạng thái UI — *proof: `npm run lint` + `next build` sạch; chuỗi thật trình duyệt → BFF → backend → MySQL trả đúng lỗi từng chặng*
- [ ] FE: màn hình theo `wire-frame.md` (kanban, danh sách, tạo, chi tiết, thống kê) — *proof: chạy local với BE thật*
- [x] CI cho `fe` (job `frontend`: `npm ci` + lint + `next build`) — *proof: YAML hợp lệ 6 job, `npm ci` + lint xanh local*
- [x] Đổi tên kỹ thuật `NodeRegistry` → **OpsBoard** (csproj, namespace, assembly, Dockerfile, Makefile, ci.yml, `DB_NAME` local) — *proof: `make test` 12 pass, `make lint` sạch sau khi đổi*
- [ ] Dockerfile cho `fe` + Trivy scan image `fe`, CD hai service, Terraform web app thứ hai + access restriction — *Q10 đã chốt: hai service*
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

## Rủi ro đã biết
- Máy làm việc dùng hotspot điện thoại → IP công khai động: ảnh hưởng firewall MySQL, access restriction (D13) và **cách lấy bằng chứng M6** (hotspot + điện thoại đó dùng chung IP → phải mượn mạng khác). Chi tiết: `notes/d2.md`.
- **D13 đo ra cụ thể hơn (2026-09-23):** không phải "IP đổi theo thời gian" mà là **hai IP dùng song song** — CGNAT nhà mạng NAT mỗi kết nối qua một trong hai địa chỉ thoát (70 mẫu `curl -4`, ~50/50, không có cái thứ ba). Mọi whitelist phải khai cả hai, nếu không thì cứ hai request có một cái bị chặn. Cloudflare WARP nếu bật còn làm hỏng phép đo nặng hơn (dải anycast dùng chung + ép đi IPv6) → **tắt WARP trước khi đo IP**. `known-issues.md` #11.

## Recovery
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

# Azure App Service + CI/CD + Monitoring — kế hoạch 5 tuần

**Status:** active
**Opened:** 2026-09-15
**Goal:** Một repo mà người thứ ba `terraform apply` + merge vào `main` là ra app chạy trên App Service, đủ bằng chứng M1–M11 trong `evidence/`, demo live D25.

## Authority

- Yêu cầu, lịch, deliverables: `a.md` (mục 2, 4, 6, 7, 8).
- Luật làm việc của project: `CLAUDE.md`.
- **Chưa định nghĩa (phải hỏi mentor, chặn bước liên quan):**
  - Q1. M11 "không enable App Insights" vs `/boom` "Alert + App Insights" vs lịch D20 → được bật App Insights cho exception không? (chặn D20)
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
- [ ] `make up` thật + verify Portal + `make down` + `make check-empty` — *proof: chưa chạy, bị Azure 429 throttle khi tạo App Service Plan, xem `known-issues.md` #6*

### D10 — **GATE**
- [ ] `terraform destroy` → `apply` sạch, **không thao tác tay**, lưu log thô → `evidence/M8.md` — *proof: log 2 lệnh*
- [ ] Xử lý hết lỗi thời gian lan truyền RBAC / soft-delete nếu gặp, ghi vào `known-issues.md`
- [ ] Trả lời mentor bằng lời: state · lock · dependency (implicit vs `depends_on`) · vì sao bootstrap tách riêng
- [ ] Nếu không qua: dừng, thu hẹp scope theo mentor. **Không kéo dài.**

---

## Tuần 3 — D11–D15 · Container, identity, network, CI mở rộng

### D11 — Container deploy qua MI
- [ ] Web App cấu hình pull ACR bằng managed identity (user-assigned client id) — *proof: app chạy image từ ACR, ACR admin = disabled* → `evidence/M1.md`
- [ ] Push image tay lần đầu (tag = git SHA, không `latest`) — *proof: `/version` = SHA*

### D12 — Key Vault reference + MySQL
- [ ] App settings dùng `@Microsoft.KeyVault(...)` + chỉ định identity dùng cho KV reference — *proof: Portal hiển thị reference "resolved" xanh*
- [ ] Kết nối MySQL qua TLS; `/items` đọc ghi trên Azure — *proof: curl* → `evidence/M3.md`
- [ ] Rà soát: không còn secret plaintext nào trong app settings — *proof: screenshot* → `evidence/M4.md`
- [ ] **Chứng minh ngược M5:** gỡ role MI khỏi KV → refresh reference/restart → app gãy → trả role → app sống lại — *proof: log từng bước* → `evidence/M5.md` (sau đó `apply` lại để không lệch state)

### D13 — IP whitelist
- [ ] Access restrictions cho prod slot, staging slot và SCM site; default deny — *proof: plan*
- [ ] curl từ IP cho phép → 200; từ hotspot điện thoại → 403 — *proof: log 2 lần curl kèm IP nguồn* → `evidence/M6.md`
- [ ] Ghi vấn đề: runner GitHub không nằm trong whitelist → cách xử lý cho CD tuần 4 (Decision)

### D14 — CI mở rộng
- [ ] Job lint + unit test — *proof: PR xanh*
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

### D20 — Cost report + App Insights (theo Q1)
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

### D22 — Alert + runbook + trigger thật
- [ ] **Chốt Q5 trước hôm nay** (credit hết hạn D23)
- [ ] Action group email; 3 alert: 5xx (theo Q3) · CPU cao · MySQL active connections — *proof: plan*
- [ ] Trigger thật ≥ 1 alert (`/boom` hoặc `/load`) → email đến — *proof: screenshot email + alert history* → `evidence/M11.md`
- [ ] `runbook.md` cho alert nghiêm trọng nhất: triệu chứng · xác nhận (query nào) · xử lý · rollback (swap ngược) · escalate

### D23 — Agent giới hạn quyền + cross-review 2
- [ ] Bài agent giới hạn quyền (theo hướng dẫn mentor) — *proof: theo yêu cầu bài*
- [ ] Cross-review lần 2 → `review-<tên>.md`

### D24 — Incident drill + hoàn thiện
- [ ] Drill: gây sự cố (deploy bản lỗi / cắt quyền KV) → làm theo runbook → rollback — *proof: timeline ghi lại*
- [ ] `destroy` → `apply` lần cuối từ repo sạch theo đúng `README.md` — *proof: log* → `evidence/M8.md`
- [ ] Hoàn thiện `architecture.md` (mermaid, tách luồng traffic và luồng auth), `README.md`, `known-issues.md`, `ai-failure-log.md` đủ 6–8 case
- [ ] Soát `evidence/M1.md`…`M11.md` đủ 11 file, mỗi file có log/screenshot thật

### D25 — Demo 45 phút (live, không slide)
- [ ] Kịch bản demo theo thứ tự: repo → CI chặn secret → merge → CD + poll zero-downtime → whitelist 200/403 → `/items` → xoá quyền KV → `/load` autoscale → `/boom` alert → dashboard/KQL → cost
- [ ] `make up` trước demo ≥ 30 phút; `make down` sau demo

---

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
- 2026-09-18 — Đổi app từ Rust sang **C#/.NET 10** (ASP.NET Core MVC, kiến trúc Controller → Service → Repository, DI qua constructor) + MySqlConnector, giữ nguyên logic/endpoint/log; nhánh `feat/dotnet-rewrite`. Image runtime **không đạt lại 0 CVE tuyệt đối** như bản Rust (musl+scratch) — chọn `aspnet:10.0-noble-chiseled` framework-dependent thay vì Native AOT (đổi kiến trúc JSON quá nhiều so với lợi ích), cần đo lại bằng Trivy. Chi tiết: `notes/lang-migration-dotnet.md`.

## Rủi ro đã biết
- Máy làm việc dùng hotspot điện thoại → IP công khai động: ảnh hưởng firewall MySQL, access restriction (D13) và **cách lấy bằng chứng M6** (hotspot + điện thoại đó dùng chung IP → phải mượn mạng khác). Chi tiết: `notes/d2.md`.

## Recovery
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

# D20 — Kế hoạch chi tiết: Cost report + App Insights + tracing (M7 phần cost, nền cho M11/tracing)

Guide gốc: `docs/guides/d20-cost-report-appinsights.md` · Nhật ký: `notes/d20.md` (tạo khi làm) ·
Bằng chứng: `cost-report.md` (mới, 1 trang) + `evidence/M7.md` (thêm phần cost) · Phiên trước: `notes/d19.md`

> **Điều kiện vào D20 — ĐÃ ĐẠT phần việc (2026-09-27):** D19 xong (`evidence/M7.md` phần autoscale +
> right sizing, giữ **P0v3**; 2 ảnh Portal M7 đã chụp 28/09). Môi trường `jcip0s` **đang bật** theo
> quyết định người dùng. **Q1 (App Insights) mentor chưa trả lời** (`known-issues.md` #5) — plan đang
> "mặc định hướng (a) workspace-based, đánh dấu tạm".

## Đọc 60 giây này trước

| | |
|---|---|
| **Hai việc độc lập** | (1) **Cost report** — chỉ đọc + viết, không tốn tiền, không phụ thuộc Q1. (2) **App Insights + OpenTelemetry** — code + Terraform + apply, phụ thuộc Q1. Làm (1) trước: nó chắc chắn xong được trong ngày. |
| **Tốn tiền?** | Cost report: **không**. App Insights: Log Analytics workspace + App Insights **workspace-based** — ingest **5 GB đầu miễn phí**, sau đó **$3,22/GB** (Central India, Retail Prices API 2026-09-27). Rủi ro thật là **ingest phình khi poll/tải** (xem quyết định E), không phải phí cố định. `terraform apply` + merge (= CD swap) ⚠️ hỏi người dùng. |
| **Ai chạy** | AI: code, Terraform, script, tài liệu, lệnh `az` chỉ đọc. 👤 **Người dùng**: ảnh Cost Analysis (Portal — CLI **không** trả được số tiền, xem dữ kiện), ảnh App Insights Failures, xác nhận apply/merge. Test tải/poll lên production: classifier Claude Code từng chặn AI chạy `load.sh` ở D19 → người dùng chạy `! …` nếu cần. |
| **Xong khi** (guide) | `cost-report.md` 1 trang, số thật, 3 biện pháp có bằng chứng · `evidence/M7.md` · App Insights xử lý theo Q1 |
| **Sau D20** | D21 (Log Analytics diagnostic settings, KQL, dashboard) dùng lại **cùng workspace** tạo ở D20. |

## Dữ kiện đã đọc từ repo / Azure (đừng đoán lại)

| Dữ kiện | Nguồn | Hệ quả cho D20 |
|---|---|---|
| **Q1 chưa có trả lời**; plan: "mặc định (a) workspace-based App Insights, đánh dấu tạm" | plan dòng Q1, `known-issues.md` #5 | Quyết định A. Làm theo mặc định nhưng ghi rõ "tạm", dễ gỡ (một cờ/biến) |
| **M11: "Dashboard (không enable App Insight)"**; `/boom`: "Alert + App Insights"; brief 21/09 đòi **distributed tracing** | `topic.md` §2, §M11, §9 | App Insights **chỉ** làm backend cho trace + exception. Dashboard M11 (D21) vẫn dựng từ platform metrics + Log Analytics, **không** dùng App Insights |
| **Chưa có Log Analytics workspace** nào trong `infra/` | `grep log_analytics infra` = rỗng | App Insights workspace-based cần workspace → D20 tạo workspace (D21 dùng lại). Đặt retention + daily cap ngay từ đầu (quyết định B) |
| `be` .NET **net10.0**, chỉ có `MySqlConnector` 2.4.0 + `Swashbuckle` — **chưa có package OpenTelemetry nào** | `app/be/OpsBoard.csproj` | Thêm dependency mới → Decision + Trivy (quyết định D) |
| `TraceIdMiddleware`: lấy trace id từ `Activity.Current` **trước**, rồi `traceparent`, rồi sinh ngẫu nhiên; comment ghi "Activity.Current có giá trị khi CÓ listener (OpenTelemetry ở D20)" | `app/be/Middleware/TraceIdMiddleware.cs` | Khi bật OTel, ASP.NET Core tự tạo Activity và **tự nhận** `traceparent` → `X-Trace-Id` = `operation_Id` của App Insights mà không cần sửa middleware. Test hiện có (`MoiResponse_CoHeaderTraceId`) phải vẫn xanh |
| Log JSON đã có `trace_id` (RequestLoggingMiddleware), **chưa có `span_id`** | `app/be/Middleware/RequestLoggingMiddleware.cs:38` | Checkbox plan D20: thêm `span_id` từ `Activity.Current` |
| **`/boom` KHÔNG ném exception** — log level error rồi `return StatusCode(500, …)` | `app/be/Controllers/BoomController.cs` | App Insights → Failures sẽ thấy **request 500** nhưng **không có exception** để chụp. Quyết định F |
| `fe` chỉ **chuyển tiếp** `traceparent` nếu request tới nó đã có (`readTraceparent`); `fe` không tạo span | `app/fe/src/lib/http.ts:7` | Trình duyệt thường **không** gửi `traceparent` → hôm nay chặng `fe → be` không nối thành một trace. Quyết định G |
| MySQL `B_Standard_B1ms`, `backup_retention_days = 1`, `geo_redundant_backup_enabled = false`, không HA, `auto_grow_enabled = false` | `infra/app/db.tf:29-43` | Biện pháp tiết kiệm #1 **đã áp dụng thật**, bằng chứng = code + `az mysql flexible-server show` |
| Autoscale max 2; D19 instance thứ 2 chỉ sống ~12 phút (≈ $0,016) | `evidence/M7.md` mục 2 | Biện pháp #2 **đã áp dụng thật**, có số |
| ACR **Basic**, Key Vault **standard**, Defender: mọi plan trả phí **Free** (D1) | `infra/app/acr.tf:11`, `keyvault.tf:17`, plan mục Validation 15/09 | Ứng viên biện pháp #3 |
| `make down` theo ca: **đúng cho D8–D16**, nhưng **từ 24/09 14:50 môi trường bật liên tục** theo quyết định người dùng (suffix `jcip0s`) | plan Recovery 24/09 → 27/09 | Biện pháp "không chạy qua đêm" **không còn đúng cho 3+ ngày gần nhất** — cost report phải nói thật (bẫy "biện pháp sẽ làm → không tính") |
| `az consumption usage list` (Free Trial) trả 330 dòng nhưng **`pretaxCost` = "None"** mọi dòng | chạy thử 2026-09-27 (chỉ đọc) | **CLI không cho số tiền** với subscription này → số thật lấy từ **Cost Analysis trên Portal** (👤 chụp). Có thể thử Cost Management Query API ở Pha A (chỉ đọc), không trông vào nó |
| Portal hiện **credit còn lại $181,86** (03:21Z 2026-09-28) — Free Trial $200 | popup Portal, ghi ở `notes/d19.md` mục "Ảnh Portal" | Đối chiếu nhanh với tổng actual cost của Cost Analysis (≈ $18 đã dùng từ 15/09 nếu không có phí khác trừ vào credit) — không thay được số Cost Analysis |
| Tag `project = vsf` gắn cho mọi resource từ D7 | `infra/app/locals.tf` `tags` | Lọc Cost Analysis theo tag được (guide bước 5) |
| Giá plan Central India: P0v3 $0,082/giờ (bảng D19) | `notes/d19-prep.md`, `evidence/M7.md` mục 4 | Tra lại lúc viết cost report (guide: giá có thể đổi) |

## Quyết định phải chốt TRƯỚC khi làm

Ghi câu trả lời vào `notes/d20.md` mục Decisions.

> **Đã chốt 2026-09-28 (người dùng: "theo đề xuất của bạn"):** **B = (a)** retention 30 ngày + daily cap
> 0,2 GB/ngày · **F = (a)** `/boom` `throw` exception thật. A, C, D, E, G, H chưa được hỏi riêng — mặc định
> theo đề xuất trong bảng, xác nhận lại đầu phiên D20.

| # | Câu hỏi | Lựa chọn | Đề xuất |
|---|---|---|---|
| A | Q1 chưa trả lời — có dựng App Insights không? | (a) dựng workspace-based App Insights, ghi "tạm theo mặc định Q1", gỡ được bằng một biến · (b) chờ mentor, D20 chỉ làm cost report + `span_id` · (c) OTel → backend tự dựng (Jaeger/Tempo) | **(a)**, nhưng làm **sau** cost report. Plan đã chọn mặc định (a); brief đòi distributed tracing, không có backend thì không chứng minh được. (c) thêm hạ tầng tự vận hành, trái tinh thần tiết kiệm M7. Thêm biến Terraform `enable_app_insights` (mặc định `true`) để mentor nói "không" thì tắt bằng một dòng |
| B | Log Analytics workspace: retention + daily cap — **ĐÃ CHỐT (a)** | (a) retention **30 ngày** + `daily_quota_gb` **0,2** · (b) retention 30, không cap · (c) cap 1 GB | **(a)** — đề xuất, **cần người dùng duyệt** (giới hạn mới, luật harness). 0,2 GB/ngày × 31 ngày ≈ 6 GB/tháng, sát mức 5 GB miễn phí; chạm cap thì ngừng thu tới hết ngày (mất telemetry, **không** mất tiền). Retention 30 ngày đủ tới demo D25 |
| C | Connection string App Insights để đâu | (a) Key Vault secret + `@Microsoft.KeyVault(...)` như `DB_PASSWORD` · (b) app setting trực tiếp từ attribute Terraform | **(a)** — checkbox plan D20 ghi rõ "lưu Key Vault, tham chiếu". Guide nói connection string "không phải secret", nhưng (a) không tốn thêm (MI đã có quyền đọc secret từ D12) và giữ một quy tắc duy nhất: app settings không có giá trị nhạy cảm. Ghi rõ lý do để không ai "sửa" ngược lại |
| D | Thư viện OTel cho `be` | (a) `Azure.Monitor.OpenTelemetry.AspNetCore` (distro: ASP.NET Core + HttpClient + exporter) + `AddSource("MySqlConnector")` · (b) OpenTelemetry SDK + OTLP exporter + collector | **(a)**: một package, exporter có sẵn, MySqlConnector tự phát `ActivitySource` tên `MySqlConnector` (đã kiểm trong DLL 2.4.0 ở cache NuGet máy, 2026-09-27) — chỉ cần đăng ký source là có span DB. (b) cần collector — thêm hạ tầng. **Dependency mới** → Decision trong plan + Trivy `be` phải vẫn 0 CRITICAL/HIGH |
| E | Sampling + lọc telemetry | (a) 100% nhưng **bỏ** `/health` và `/version` khỏi trace · (b) 100% mọi thứ · (c) sampling cố định 10% | **(a)**. Plan ghi "sampling 100% (lưu lượng thấp)" — đúng với người dùng thật, **sai** với lưu lượng máy: health check + `m2-poll.sh` (3 req/s) ≈ 260 000 request/ngày, đủ ăn hết 5 GB miễn phí trong vài tuần. Probe không mang thông tin trace. (c) làm mất trace của `/boom`/`/items` hiếm → không chứng minh được gì |
| F | `/boom` phải có **exception** trong Failures — **ĐÃ CHỐT (a) `throw`** | (a) `throw` thật (đúng chữ `topic.md` §2 "ném exception" và hướng đã ghi ở `docs/docs_app/brief.md` R6: "nếu Q1 cho bật App Insights, đổi `/boom` sang ném exception thật") · (b) giữ `return StatusCode(500, …)`, chỉ gắn `Activity.Current?.AddException(ex)` | **(a)** — repo đã ghi hướng này từ trước (R6), và `topic.md` nói "ném exception". Hệ quả phải xử lý: app **chưa có** exception handler (`grep UseExceptionHandler app/be` rỗng) → exception không bắt sẽ trả 500 body rỗng; test `HttpTests.cs:90-91` chỉ kiểm mã 500 nên vẫn xanh, nhưng phải đối chiếu `docs/docs_app/api-spec.md` xem body `ErrorResponse` "boom" có là hợp đồng không — nếu có, thêm exception handler trả `ErrorResponse` 500 + log JSON một dòng (giữ `trace_id`). (b) rẻ hơn nhưng lệch chữ đề bài và lệch R6. Kiểm: Failures → Exceptions thấy loại exception + `operation_Id` = `X-Trace-Id`; tiến trình sống tiếp sau `/boom` |
| G | Chặng `fe → be` trong trace | (a) D20 chỉ `be`; `fe` để D21 (checkbox "end-to-end transaction" nằm ở D21) · (b) D20 làm cả `fe` (`@azure/monitor-opentelemetry` + `instrumentation.ts` của Next.js) | **(a)**. D20 đã có 2 khối việc; `fe` là runtime khác (Node, standalone build, Trivy riêng). Ghi rõ trong `evidence`/notes: D20 trace chỉ phủ `be` + MySQL |
| H | Số chi phí thật lấy thế nào | (a) 👤 Portal Cost Analysis (4 ảnh theo guide) + ghi số tay vào `cost-report.md` · (b) thử Cost Management Query API bằng CLI, rơi về (a) | **(b) → (a)**: thử API chỉ đọc một lần (không cài thêm extension nếu không có sẵn); Consumption API đã chứng minh không cho số. Ảnh Portal guide **bắt buộc** nên (a) đằng nào cũng làm |

## Hiểu trước khi làm — 5 điều

1. **Cost report là bài viết có số, không phải bài code.** Ba biện pháp phải là thứ **đã làm, có bằng
   chứng** (guide: "sẽ làm → không tính"). Ứng viên có bằng chứng thật: MySQL tối giản (`db.tf`),
   autoscale max 2 thay vì cố định 2 (D19 số thật), ACR Basic + không Defender trả phí, tắt môi trường
   theo ca (**chỉ đúng tới 24/09** — nói thật phần 24/09 → nay).
2. **Credit $200 che hoá đơn.** Hoá đơn có thể hiện 0 nhưng Cost Analysis vẫn có chi phí thực tế
   (actual cost) — báo cáo **actual cost**, ghi giờ lấy số (dữ liệu trễ 8–24 giờ).
3. **App Insights workspace-based = dữ liệu nằm trong Log Analytics workspace**, tính tiền theo ingest
   của workspace. Daily cap đặt ở **workspace** (quyết định B). App Insights là "cửa sổ đọc" cho trace.
4. **OTel bật lên là `Activity.Current` có giá trị** → `TraceIdMiddleware` dùng nhánh 1 (trace id của
   Activity), ASP.NET Core tự đọc `traceparent` đến. Nghĩa là `X-Trace-Id` (header) = `trace_id` (log
   JSON) = `operation_Id` (App Insights) — ba chỗ **một** giá trị. Đó là bằng chứng "truy vết alert →
   log/request" của brief.
5. **Distro Azure Monitor cần connection string lúc khởi động.** Test (`dotnet test`), CI và chạy
   local **không** có nó → chỉ đăng ký exporter khi biến `APPLICATIONINSIGHTS_CONNECTION_STRING` có
   giá trị. Không làm thế là CI đỏ hoặc app không khởi động được ở local (bẫy T2).

---

## Pha A — Cost report (KHÔNG tốn tiền) · ~1.5 giờ

Nhánh: `git fetch && git switch -c docs/d20-cost-report-a origin/main` (tên `docs/d20-cost-report` đã dùng ngày 28/09 để đưa M2 lần 4 + ảnh M7 + dọn nợ ảnh vào `main` — PR #58)

- [x] A0. 2 ảnh M7 (D19) — đã chụp 2026-09-28 (`evidence/d19/screenshots/`)
- [ ] A1. Thử Cost Management Query API **một lần**, chỉ đọc (quyết định H): actual cost theo ngày +
      theo service từ 2026-09-15. Không có số → ghi "API không cho số với Free Trial" vào `notes/d20.md`, dùng A2
- [ ] A2. 👤 Portal → Cost Management → **Cost analysis**, scope subscription, 15/09 → hôm nay, **Actual
      cost**: (1) Daily costs · (2) Group by Service name · (3) Group by Resource · (4) lọc tag
      `project = vsf`. Ghi **giờ lấy số**. Lưu `evidence/d20/screenshots/` (luật che:
      `evidence/screenshots-convention.md`)
- [ ] A3. Bằng chứng cho 3 biện pháp (chỉ đọc):
      - MySQL: `az mysql flexible-server show -g rg-vsf-dev -n <tên> --query "{sku:sku.name, backup:backup, ha:highAvailability, storage:storage}"` → `evidence/raw/d20-mysql-cost-settings.json`
      - Autoscale: dẫn `evidence/M7.md` mục 2 (instance thứ 2 ~12 phút ≈ $0,016) + so với chạy cố định 2 instance
      - Tắt theo ca: Daily costs (A2) thấy ngày ~0 **trước** 24/09; ghi thẳng: từ 24/09 bật liên tục theo quyết định người dùng, ước tính số tiền của những ngày đó
- [ ] A4. Tra lại giá (Retail Prices API, Central India): P0v3, MySQL B1ms (Southeast Asia!), ACR Basic,
      Key Vault ops, Log Analytics — **MySQL ở Southeast Asia, app ở Central India** (D9) → tra đúng region từng dịch vụ
- [ ] A5. `cost-report.md` (gốc repo, **1 trang**) theo khung guide §2: tier + lý do (dẫn bảng right sizing
      `evidence/M7.md` mục 4) · autoscale · 3 biện pháp + bằng chứng + tiết kiệm ước tính · chi phí thật
      (tổng + theo dịch vụ) · "nếu chạy 24/7" · chưa tối ưu. Mỗi con số có nguồn (ảnh/lệnh/file)
- [ ] A6. `evidence/M7.md`: thêm mục "Cost report" (link `cost-report.md`, ảnh Cost Analysis); đổi
      banner trạng thái. `notes/d20.md` Pha A
- [ ] A7. PR `docs/d20-cost-report` → CI 8/8 → ⚠️ merge = CD swap thật (hỏi người dùng)

## Pha B — OpenTelemetry trong `be` (KHÔNG tốn tiền — chạy local) · ~2 giờ

Nhánh: `feat/d20-otel-be` (sau khi Pha A merge, hoặc song song nếu người dùng muốn — **không mở 2 PR cùng lúc**)

- [ ] B1. `app/be/OpsBoard.csproj`: `Azure.Monitor.OpenTelemetry.AspNetCore` (bản stable mới nhất —
      tra NuGet, ghi version vào Decision). `dotnet restore` + xem package kéo theo những gì
- [ ] B2. `ApiSetup`/`Program.cs`: `AddOpenTelemetry().UseAzureMonitor()` **chỉ khi**
      `APPLICATIONINSIGHTS_CONNECTION_STRING` có giá trị (điều 5); `WithTracing(t => t.AddSource("MySqlConnector"))`;
      lọc `/health`, `/version` (quyết định E). **Không** bật logging exporter của OTel (log vẫn đi JSON
      stdout → Log Analytics ở D21; tránh ingest hai lần)
- [ ] B3. `RequestLoggingMiddleware`: thêm `span_id` (`Activity.Current?.SpanId`), giữ `trace_id` như cũ
- [ ] B4. `/boom` theo quyết định F (đề xuất: `throw` thật + exception handler nếu `api-spec.md` coi body
      `ErrorResponse("boom")` là hợp đồng); cập nhật R6 trong `docs/docs_app/brief.md` khi xong
- [ ] B5. Test: `make test` (tất cả test cũ xanh, đặc biệt `MoiResponse_CoHeaderTraceId`) + test mới:
      có `traceparent` đến → `X-Trace-Id` = trace-id đó; log có `span_id`; `/boom` vẫn 500 + body cũ.
      `make lint` · `dotnet format --verify-no-changes`
- [ ] B6. Chạy local **không** có connection string → app khởi động, không lỗi, không gửi gì ra ngoài
- [ ] B7. `docker build` + Trivy `be` (CI làm) — 0 CRITICAL/HIGH mới; nếu có → xử lý như D14 (bớt thứ trong image), không nới chính sách
- [ ] B8. PR có `## AI usage` + Decision "dependency mới" trong plan

## Pha C — Terraform: workspace + App Insights (plan không tốn tiền; apply ⚠️)

- [ ] C1. `infra/app/monitoring.tf` (mới): `azurerm_log_analytics_workspace` (retention 30, `daily_quota_gb`
      theo quyết định B, SKU `PerGB2018`) + `azurerm_application_insights` (`workspace_id`, `application_type = "web"`),
      đều `count = var.enable_app_insights ? 1 : 0`, tags `local.tags`
- [ ] C2. `keyvault.tf`: secret `appinsights-connection-string` (giá trị = attribute Terraform, **không**
      có trong repo); `app.tf`: app setting `APPLICATIONINSIGHTS_CONNECTION_STRING =
      "@Microsoft.KeyVault(SecretUri=…versionless_id)"` cho **site + slot staging** của `be` (slot phải
      giống site — comment `local.app_settings`). `fe` chưa (quyết định G)
- [ ] C3. `terraform fmt` · `validate` · `plan -lock=false` → mong đợi: **3 to add** (workspace, App
      Insights, secret) + **2 to change** (app settings `be` site + slot). Khác → dừng, đọc diff
- [ ] C4. Kiểm quyền đọc: identity CI plan (Reader RG) đọc được workspace/App Insights; MI của app đọc được
      secret mới — MI có `Key Vault Secrets User` ở scope **vault** (`infra/app/keyvault.tf:48-50`, đọc 27/09) nên
      mong đợi có sẵn; identity CI plan cũng có Secrets User ở vault (`:57-59`). Kiểm lại lúc D2 (Resolved)
- [ ] C5. PR → CI (nhớ: CI plan luôn có thêm 4 change `ip_restriction` giả do thiếu tfvars — `notes/d19.md` A5)

## Pha D — Apply + kiểm chứng trên Azure (⚠️ apply và merge phải hỏi)

- [ ] D1. ⚠️ `terraform apply` từ `main` sau khi PR C merge — kiểm `pwd` + `git log -1` + `git diff origin/main -- infra/` rỗng (bài học #11); `plan -out` rồi apply đúng file đó; xoá file plan ngay (chứa secret)
- [ ] D2. `az webapp config appsettings list` 2 slot `be`: `APPLICATIONINSIGHTS_CONNECTION_STRING` là
      KV reference, trạng thái **Resolved** (Portal hoặc `az rest` đọc `configreferences`) — **không** in giá trị
- [ ] D3. Merge PR B (= CD swap, ⚠️ hỏi) → production `be` chạy code OTel. Tuỳ chọn: bật `m2-poll.sh` quanh lần merge (lần đo M2 thứ 4 cho #21)
- [ ] D4. Sinh traffic có chủ đích: `GET /items` (có `traceparent` tự tạo), `POST /items`, `GET /boom` —
      ghi `X-Trace-Id` từng request vào `evidence/raw/d20-trace-requests.log`
- [ ] D5. Chờ 2–5 phút (ingest trễ). Kiểm bằng KQL (`az monitor app-insights query`, chỉ đọc):
      `requests | where operation_Id == "<trace id>"` · `dependencies` có span MySQL cùng `operation_Id` ·
      `exceptions` có exception của `/boom`. Lưu kết quả thô
- [ ] D6. 👤 Ảnh: App Insights → **Transaction search/end-to-end** của một `/items` (thấy span DB) ·
      **Failures → Exceptions** của `/boom`. Chưa chụp → thêm vào `docs/plans/active/azure-app-service-internship.md` mục "Còn nợ"
- [ ] D7. Đối chiếu một request: `X-Trace-Id` (header) = `trace_id` (log JSON, Log stream hoặc
      `az webapp log tail`) = `operation_Id` (App Insights) → ghi bảng trong evidence
- [ ] D8. Kiểm ingest sau 1 giờ: `Usage and estimated costs` của workspace hoặc KQL `Usage` →
      ước tính GB/ngày; nếu vượt cap B → xem lại lọc E

## Pha E — Ghi chép + review + cuối phiên

- [ ] `notes/d20.md` (quyết định, số liệu, kế hoạch nói sai) · `evidence/M7.md` (cost) · evidence cho
      tracing (đề xuất `evidence/tracing.md` hoặc mục trong `M11.md` — hỏi người dùng nơi đặt) ·
      `known-issues.md` #5 cập nhật Q1 · plan: tick D20 + Recovery + Decision "dependency mới"
- [ ] Review độc lập (sub-agent) trước PR chốt
- [ ] Cuối phiên: capacity plan = 1, không script nào chạy, nhắc chi phí (giờ có thêm workspace ingest) + hỏi `make down`
      (**chỉ sau khi đã có đủ ảnh M7 + D20**)

---

## Bảng bẫy

| # | Bẫy | Hậu quả | Tránh |
|---|---|---|---|
| T1 | Viết biện pháp "sẽ làm" hoặc "tắt theo ca" mà không nói môi trường bật liên tục từ 24/09 | Cost report sai sự thật — bẫy số 1 của guide | Điều 1; A3 ghi thẳng |
| T2 | Đăng ký Azure Monitor exporter vô điều kiện | `dotnet test`/CI/local lỗi vì thiếu connection string | Điều 5; B2 + B6 |
| T3 | 100% sampling kể cả `/health`, `/version`, poll | Ingest vượt 5 GB miễn phí, chạm cap, mất telemetry đúng lúc demo | Quyết định E; D8 đo lại |
| T4 | Bật cả OTel log exporter lẫn log stdout → Log Analytics (D21) | Log vào workspace hai lần, tiền ×2, KQL trùng dòng | B2: không bật log exporter |
| T5 | Chụp Cost Analysis quá sớm / không ghi giờ | Thiếu 1 ngày gần nhất, số không đối chiếu được | Ghi giờ lấy số; dữ liệu trễ 8–24h |
| T6 | Báo cáo số trên hoá đơn (0 vì credit) | Nói "tốn 0 đồng" — sai | Điều 2: actual cost |
| T7 | Connection string plaintext trong app settings / tfvars / log | Lệch quy tắc M4 của project | Quyết định C; D2 kiểm Resolved, không in giá trị |
| T8 | Slot staging thiếu app setting mới (chỉ gắn site) | Sau swap, production mất telemetry | C2: site **và** slot; D2 kiểm cả hai |
| T9 | Dựng dashboard M11 trên App Insights | Trái chữ `topic.md` M11 ("không enable App Insight") | App Insights chỉ cho trace + exception; dashboard D21 dùng metric nền tảng + Log Analytics |
| T10 | `make down` trước khi chụp ảnh M7/D20 | Mất metric, Run history, Cost view theo resource | Pha A0, Pha E |
| T11 | Tra giá MySQL ở Central India | Sai giá — MySQL ở **Southeast Asia** (D9) | A4 |
| T12 | Dùng mốc phút của metric Azure để ghép timeline | Lệch 1–2 phút (đã thấy ở D19) | Dùng Activity Log / log client làm mốc |
| T13 | Merge PR trong lúc đang đo/tải | Swap chồng lên phép đo | Như D19 điều 5 |

## Gợi ý trả lời 2 câu tự kiểm tra (guide) — điền số thật ở Pha A

1. **Biện pháp nào tiết kiệm nhiều nhất và vì sao?** Dự kiến: tắt môi trường theo ca (D8–D23) — plan
   P0v3 + MySQL chạy 24/7 là phần lớn chi phí, tắt ~16–20 giờ/ngày cắt gần tương ứng. **Kiểm bằng
   Daily costs** (A2), và trừ đi phần 24/09 → nay đã bật liên tục.
2. **Nếu chạy 24/7 cho người dùng thật, đổi gì?** Giữ P0v3 + autoscale (D19: CPU bình thường ~10%);
   cân nhắc reserved/savings plan cho plan thường trực; MySQL: HA + backup dài hơn (đổi tiền lấy độ bền);
   bỏ tắt theo ca; App Insights sampling thật (không 100%). Điền số "24/7 ≈ $…/tháng" từ giá A4.

## Ước lượng

| Pha | Thời gian | Tốn tiền |
|---|---|---|
| A — cost report | ~1.5 giờ | không (merge = 1 lần CD) |
| B — OTel `be` local | ~2 giờ | không |
| C — Terraform + PR | ~1 giờ | không |
| D — apply + kiểm | ~1 giờ | workspace ingest, dự kiến ≪ 5 GB miễn phí nếu lọc E |
| E — ghi chép + review | ~1 giờ | — |

Nếu một phiên không đủ: **Pha A là phần phải xong trong D20** (deliverable `cost-report.md`); B–D có
thể tràn sang đầu D21 vì D21 cần cùng workspace.

## Lưu ý cho phiên có AI

- Kế hoạch do Claude Code (Opus 5.5) viết 2026-09-27, ngay sau khi chốt D19. Dữ kiện ở bảng trên có
  file:dòng hoặc lệnh chỉ đọc cùng ngày; giá Log Analytics tra Retail Prices API cùng ngày — **tra lại**.
- Luật phiên: `terraform apply`, merge PR (= CD swap), test tải phải hỏi người dùng. Classifier Claude
  Code có thể chặn cả khi người dùng đã đồng ý (D19: `load.sh`) — khi đó người dùng chạy `! …`, không lách.
- Lệnh `gh`/`az` chạy trần; script dài viết thành file. Dừng script nền: `pgrep -o -f '^bash scripts/<tên>.sh'`
  + `ps -o pid,ppid,args` (subshell con cùng dòng lệnh — `ai-failure-log.md` #34).
- Activity Log / Portal export có thể chứa **email người dùng** (trường `caller`) — che trước khi lưu vào repo (D19).
- Node 24 + .NET local: `export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$HOME/.nvm/versions/node/v24.21.0/bin:$PATH`.
- `terraform.tfvars` bị gitignore — worktree mới chép từ checkout chính (đọc trước khi chép).

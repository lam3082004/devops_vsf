# D21 — Kế hoạch chi tiết: Logging (diagnostic settings · KQL · Workbook · nghiên cứu giải pháp) — M11 phần 1–3

Guide gốc: `docs/guides/d21-logging.md` · Nhật ký: `notes/d21.md` (tạo khi làm) · Bằng chứng:
`evidence/M11.md` (mới — phần dashboard/log), `docs/logging.md` (mới) · Phiên trước: `notes/d20.md`

> **Điều kiện vào D21 — ĐÃ ĐẠT (2026-09-28):** D20 xong. Workspace `log-vsf-jcip0s` **đã có** (D20, PerGB2018,
> retention 30 ngày, cap 0,2 GB/ngày) và App Insights workspace-based đang nhận trace của `be` (`evidence/tracing.md`).
> Môi trường `jcip0s` **đang bật**. Production `be` + `fe` = `5a8d982`.

## Đọc 60 giây này trước

| | |
|---|---|
| **Việc chính** | (1) Terraform **diagnostic settings** đẩy log App Service vào workspace sẵn có · (2) 7 truy vấn KQL + 1 truy vấn nối trace ↔ log → `docs/logging.md` · (3) **Workbook bằng Terraform**: 3 hàng (app perf · infra App Service · infra MySQL) + hàng log · (4) `docs/logging.md` so sánh 3 giải pháp, có giá |
| **Không làm** | Dashboard trên App Insights (`topic.md` M11: "không enable App Insight" → **dashboard không dùng App Insights**; App Insights chỉ là nơi đọc trace, bẫy T9 của D20). Alert + action group là **D22** |
| **Tốn tiền?** | Diagnostic settings: tiền **ingest** ($3,22/GB Central India, 5 GB/tháng đầu miễn phí/billing account). Workbook: 0. Metric nền tảng đọc trực tiếp: 0. `terraform apply` + merge (= CD swap) ⚠️ hỏi người dùng |
| **Ai chạy** | AI: Terraform, KQL, JSON Workbook, tài liệu, lệnh `az` chỉ đọc, gửi vài request có chủ đích. 👤 Người dùng: duyệt apply/merge, ảnh Workbook nếu extension không chụp được |
| **Xong khi** (guide) | workspace + diagnostic settings bằng Terraform · 7 truy vấn có kết quả · Workbook đủ 3 hàng + log, **sống lại sau destroy/apply** · `docs/logging.md` so sánh 3 giải pháp |

## Dữ kiện đã đọc từ repo / Azure (28/09 — đừng đoán lại)

| Dữ kiện | Nguồn | Hệ quả cho D21 |
|---|---|---|
| Workspace `log-vsf-jcip0s` đã có, **không** theo cờ `enable_app_insights` | `infra/app/monitoring.tf` (PR #59) | Guide §1 "tạo workspace" đã xong — D21 chỉ thêm diagnostic settings + Workbook, trỏ `azurerm_log_analytics_workspace.main.id` |
| Category của Web App: `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, `AppServicePlatformLogs`, `AppServiceIPSecAuditLogs`, `AppServiceAppLogs`, `AppServiceAuditLogs`, `AppServiceFileAuditLogs`, `AppServiceAuthenticationLogs`, `AppServiceAntivirusScanAuditLogs` + `AllMetrics` | `az monitor diagnostic-settings categories list` (be site) | Chọn ở quyết định A |
| Plan: chỉ `AllMetrics`. MySQL: `MySqlSlowLogs`, `MySqlAuditLogs`, `AllMetrics` | như trên | Quyết định B, C |
| `be` site và `fe` site **đã có** 1 diagnostic setting `obs-poc` (PoC khác, gửi Event Hub, ngoài repo); **slot staging chưa có gì** | `az monitor diagnostic-settings list` | Tối đa 5 setting/resource → thêm 1 không vướng. **Không** import/sửa/xoá `obs-poc`. Slot là resource riêng → phải khai riêng (bẫy guide) |
| Ingest hiện tại (chỉ App Insights, lúc yên): ~406 KB / 17 phút ≈ **34 MB/ngày**, 58% là `AppMetrics` | KQL `estimate_data_size` 08:03Z 28/09 | Còn ~165 MB/ngày dưới cap 0,2 GB. Slot staging sẽ gửi thêm telemetry từ lần deploy kế (nó đang chạy image cũ không có OTel) → ~60 MB/ngày |
| `scripts/m2-poll.sh` = 3 request/giây ≈ **260 000 request/ngày** | `notes/d20-prep.md` quyết định E | `AppServiceHTTPLogs` ~1–1,5 KB/dòng → poll dài 1 ngày ≈ 300–400 MB → **chạm cap**. Bẫy T3 bên dưới |
| Log app đi stdout, 1 dòng JSON, có `trace_id` + `span_id` (D20) | `Middleware/RequestLoggingMiddleware.cs` | `AppServiceConsoleLogs.ResultDescription` → `parse_json` (Q4). Nối được `trace_id` ↔ `AppRequests.OperationId` (checkbox plan D21 "KQL join") |
| MySQL ở **Southeast Asia**, workspace ở Central India | `infra/app/db.tf`, D9 | Diagnostic setting gửi chéo vùng được; metric MySQL đọc trực tiếp trong Workbook (không ingest) |
| `azurerm` **4.81.0** có `azurerm_application_insights_workbook` (tên phải là UUID, `data_json`, `source_id`) | `infra/app/.terraform.lock.hcl` | Workbook quản lý bằng Terraform, JSON để trong file template. `source_id = "azure monitor"` (không gắn App Insights — M11) |
| `make down` **sẽ gãy** khi web app PoC còn chạy trên plan `asp-vsf-dev` | `known-issues.md` #23 | Tiêu chí "Workbook sống lại sau destroy/apply" cần `make down` → phải gỡ PoC trước (việc của người dùng/repo PoC) |
| Giá 28/09: Managed Grafana Standard $0,048/giờ/node (~$35/tháng) + $6/user/tháng, Essential $6/user/tháng; VM B2s Linux $0,0448/giờ (~$33/tháng + disk); Log Analytics $3,22/GB | Retail Prices API, Central India | Bảng so sánh `docs/logging.md` (guide §5) |
| Q3 ("5xx rate" là count hay %) chưa trả lời | plan mục Câu hỏi | Workbook hiện **cả hai** (số 5xx và %) — không phải chờ |

## Quyết định phải chốt TRƯỚC khi làm

Ghi câu trả lời vào `notes/d21.md` mục Decisions.

> **Chốt 2026-09-29 (người dùng: "đầy đủ"):** A, B, D, E, G theo đề xuất; **C = (b)** bật MySQL slow log;
> **F = (a)** tracing `fe` ngay trong D21 (không đợi D22). Thực tế khác kế hoạch ở F: không dùng distro
> `@azure/monitor-opentelemetry` mà exporter + SDK trace — lý do ở `notes/d21.md` mục Pha F.

| # | Câu hỏi | Lựa chọn | Đề xuất |
|---|---|---|---|
| A | Category log cho 4 bề mặt web app (`be`, `be`-staging, `fe`, `fe`-staging) | (a) `HTTPLogs` + `ConsoleLogs` + `PlatformLogs` + `IPSecAuditLogs` · (b) như (a) bỏ `IPSecAuditLogs` · (c) mọi category | **(a)**. 3 category đầu là thứ guide đòi (Q1–Q6). `IPSecAuditLogs` cho Q7 (IP bị 403) — chính là bằng chứng M6 dạng log. Bỏ `AppLogs` (app không ghi qua logging của App Service, chỉ stdout = `ConsoleLogs`), bỏ các loại audit file/antivirus/auth (không dùng, tốn ingest). Nếu bot quét làm `IPSecAuditLogs` phình → tắt riêng nó |
| B | Metric nền tảng có đẩy vào workspace (`AllMetrics`) không | (a) **không** — Workbook đọc metric trực tiếp từ Azure Monitor · (b) có, cho mọi resource | **(a)**. Metric đã có sẵn 93 ngày miễn phí; đẩy `AllMetrics` của 6 resource (4 web app + plan + MySQL) vào workspace ≈ hàng chục MB/ngày chỉ để nhân đôi dữ liệu → ăn cap 0,2 GB. Workbook có nguồn "Azure Monitor metrics" riêng |
| C | MySQL: log `MySqlSlowLogs` | (a) không — chỉ metric (CPU, active connections, storage %) · (b) bật slow log (phải đổi server parameter `slow_query_log` + `long_query_time`) | **(a)**. M11 chỉ đòi metric MySQL; bật slow log là đổi cấu hình server (Terraform `azurerm_mysql_flexible_server_configuration`) + ingest mới. Ghi vào "làm thêm nếu còn giờ" |
| D | Vòng đời workspace khi `make down` | (a) chấp nhận mất log mỗi lần destroy (workspace nằm trong `rg-vsf-dev`) · (b) dời workspace sang stack sống lâu | **(a)**. (b) cần tầng bootstrap — mà bootstrap **không còn state** (`known-issues.md` #17), không apply được. Bằng chứng chụp/lưu KQL trong ngày. Lưu ý: workspace xoá vào soft-delete 14 ngày; tên có suffix ngẫu nhiên nên dựng lại không đụng tên cũ |
| E | Kiểm "Workbook sống lại sau destroy/apply" | (a) ghép vào **M8 lần 2** (destroy → apply toàn bộ, đang nợ từ D15) — một lần `make down`/`make up` ~45 phút, **sau khi PoC đã gỡ** (#23) · (b) chỉ tạo lại riêng Workbook (`terraform apply -replace=…`) · (c) bỏ | **(b)** — người dùng 28/09: **tạm thời không `make down`** cho tới khi có yêu cầu mới, nên (a) không làm được lúc này. Ghi rõ (b) chỉ chứng minh Workbook dựng lại được từ code, chưa thay (a); (a) để lúc người dùng cho tắt môi trường |
| F | Tracing chặng `fe → be` (hoãn từ D20 quyết định G) | (a) D21 thêm `@azure/monitor-opentelemetry` vào `fe` (Next.js `instrumentation.ts`) + app setting KV reference cho `fe` · (b) để D22 · (c) không làm, ghi known-issue | **(b)**. D21 đã đủ 4 khối việc; `fe` là runtime khác (dependency npm mới + Trivy `fe` + standalone build). Checkbox plan "dashboard 5 mảng … trace (end-to-end)" hiện đạt được với trace của `be`; chặng `fe` là phần tăng thêm |
| G | Workbook: nguồn cho ô "failure rate" | (a) metric `Http5xx` / `Requests` của Web App · (b) KQL trên `AppServiceHTTPLogs` (Q2) | **(a)** cho ô chính (không phụ thuộc ingest/cap), **(b)** làm ô phụ trong hàng log — chứng minh "không cần App Insights" (câu tự kiểm tra 2 của guide) |

## Hiểu trước khi làm — 5 điều

1. **Metric ≠ log.** Metric (Azure Monitor) là số đã gộp theo phút, lưu sẵn, đọc miễn phí, trễ 1–2 phút (đã
   thấy ở D19). Log (Log Analytics) là từng dòng sự kiện, trả tiền theo GB, trễ 2–15 phút. Dashboard dùng
   metric cho đường xu hướng, log cho "chuyện gì đã xảy ra với request này".
2. **Diagnostic setting là thứ gắn vào *từng* resource.** Slot staging là resource riêng
   (`.../sites/app-vsf-jcip0s/slots/staging`) — quên nó thì staging câm, và sau swap thì... vẫn đúng (setting
   gắn vào *slot*, không đi theo code). Khai cho cả 4 bề mặt.
3. **`AppServiceConsoleLogs.ResultDescription` là chuỗi** — dòng JSON của app. `parse_json()` từng dòng; log
   nhiều dòng sẽ vỡ (app đã 1 dòng/record từ D4).
4. **Nối trace ↔ log bằng `trace_id`.** `AppRequests.OperationId` (App Insights, cùng workspace) =
   `parse_json(ResultDescription).trace_id` (ConsoleLogs). Một `join` → từ request lỗi ra log của đúng request đó
   — nền cho "truy vết alert → request" ở D22.
5. **Cap 0,2 GB/ngày là hàng rào, không phải mục tiêu.** Chạm cap = ngừng thu tới 00:00 UTC. Đo ingest thật
   sau apply (`Usage` + `estimate_data_size`), trước khi chạy poll/tải.

---

## Pha A — Terraform diagnostic settings (plan không tốn tiền; apply ⚠️) · ~1 giờ

Nhánh: `feat/d21-diagnostics` từ `origin/main`.

- [ ] A1. `infra/app/monitoring.tf`: `azurerm_monitor_diagnostic_setting` với `for_each` trên 4 bề mặt
      (`be` = `azurerm_linux_web_app.app.id`, `be-staging` = `azurerm_linux_web_app_slot.staging.id`, `fe`, `fe-staging`),
      `log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id`, `log_analytics_destination_type` để mặc định,
      `enabled_log` theo quyết định A. **Không** khối `metric`/`enabled_metric` (quyết định B) — kiểm provider 4.81
      có đòi ít nhất một category không; nếu có, xem lại cách khai
- [ ] A2. Tên setting riêng (`diag-vsf`), khác `obs-poc`. `terraform plan -lock=false` → mong đợi **4 to add, 0 change**
      (CI: +4 change `ip_restriction` giả như mọi PR). Khác → dừng, đọc diff
- [ ] A3. PR (`## AI usage`) → CI 8/8 → ⚠️ merge (= CD swap) → ⚠️ apply từ `main` (quy trình D20 D1: `pwd`,
      `git log -1`, diff `infra/` rỗng, `plan -out`, apply file đó, xoá file plan)
- [ ] A4. Kiểm: `az monitor diagnostic-settings list` cả 4 bề mặt (thấy `diag-vsf` + `obs-poc` ở 2 site chính);
      gửi vài request (`/items`, `/boom`, `/load?seconds=5` — một lần, không phải test tải), chờ 5–15 phút, 4 bảng
      có dòng: `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, `AppServicePlatformLogs`, `AppServiceIPSecAuditLogs`
      (403: gọi thử từ một IP ngoài whitelist nếu có — không thì ghi "chưa thấy dòng nào")
- [ ] A5. Đo ingest sau 1–2 giờ: `Usage | summarize sum(Quantity) by DataType` + `estimate_data_size` → ghi GB/ngày
      ước tính vào `notes/d21.md`; nếu > 0,15 GB/ngày → xem lại A (tắt `IPSecAuditLogs` trước)

## Pha B — KQL (không tốn tiền) · ~1,5 giờ

Chạy trên workspace (Portal **Logs** hoặc `az rest` như `notes/d20.md` — không cần cài extension). Mỗi truy
vấn vào `docs/logging.md`: câu hỏi · truy vấn · kết quả (bảng thô `evidence/raw/d21-kql-*.tsv` hoặc ảnh) · 1 câu kết luận.

- [ ] Q1 request rate / 5 phút · Q2 % 5xx / 5 phút (`HTTPLogs`, `ScStatus >= 500`) · Q3 p50/p95 `TimeTaken` theo
      `CsUriStem` · Q4 `parse_json(ResultDescription)` → `level`, `path`, `status`, `duration_ms`, `trace_id` ·
      Q5 top `level == "error"` 1 giờ (thấy `boom` + `db_error` nếu có) · Q6 `PlatformLogs` khởi động/dừng container
      (thấy lần swap/restart) · Q7 `IPSecAuditLogs` theo IP nguồn (**che 2 octet cuối** trước khi lưu vào repo)
- [ ] Q8 (checkbox plan D21) nối trace ↔ log: `AppRequests | where Success == false` join Q4 theo
      `OperationId == trace_id` → một request `/boom` ra đúng dòng log `boom` của nó
- [ ] Bẫy đã biết: `TimeTaken` của `HTTPLogs` tính bằng ms; `CsUriStem` không có query string; health check
      `/health` chiếm phần lớn dòng — lọc ra khi tính rate cho người dùng

## Pha C — Workbook bằng Terraform · ~2 giờ

- [ ] C1. Dựng Workbook trên Portal (Azure Monitor → Workbooks → New) hoặc viết JSON tay theo schema
      `Notebook/1.0`: tham số `TimeRange` · hàng **App performance** (metric Web App `HttpResponseTime` avg + p95 nếu
      có, `Requests`, `Http5xx` và `Http5xx/Requests`) · hàng **Infra App Service** (metric **plan**: `CpuPercentage`,
      `MemoryPercentage`, `HttpQueueLength`) · hàng **Infra MySQL** (`cpu_percent`, `active_connections`,
      `storage_percent`) · hàng **Logs** (Q5 lỗi mới nhất, request chậm nhất Q3) · ô **trace**: Q8 (mảng "trace" của
      checkbox 5 mảng; `fe` chưa có — quyết định F) · ô **health**: metric `HealthCheckStatus` của 2 web app. Ô
      "alert đang bắn" để **D22** (chưa có alert)
- [ ] C2. Advanced editor → JSON → `infra/app/workbooks/m11.json.tftpl`; thay mọi resource ID bằng biến
      `templatefile()` (`be_id`, `fe_id`, `plan_id`, `mysql_id`, `workspace_id`). **Không** để subscription id cứng
- [ ] C3. `azurerm_application_insights_workbook`: `name` = `uuidv5("url", "vsf-m11-${local.name_suffix}")` (ổn
      định giữa các lần plan — **không** `uuid()`), `display_name`, `source_id = "azure monitor"`, `category = "workbook"`,
      `data_json = templatefile(...)`, tags. `plan` → 1 to add
- [ ] C4. PR → CI → ⚠️ merge → ⚠️ apply → mở Workbook, mọi ô có dữ liệu → ảnh (Claude in Chrome; không được thì 👤)
- [ ] C5. Quyết định E: (b) `terraform apply -replace=azurerm_application_insights_workbook.m11` → Workbook tạo
      lại y nguyên; (a) để lúc người dùng cho `make down`/`make up`

## Pha D — `docs/logging.md` (không tốn tiền) · ~1 giờ

- [ ] Bảng guide §5 với **số tra được** (ngày tra 28/09 ở trên — tra lại lúc viết): Log Analytics + Workbook (0 cố
      định, $3,22/GB) · Managed Grafana (Essential $6/user/tháng; Standard ~$35/tháng/node + $6/user) · Loki + Grafana
      tự dựng (VM B2s ~$33/tháng + disk + công vận hành)
- [ ] GB/ngày đo thật từ A5 → chi phí tháng ước tính của lựa chọn (a); 2 nút vặn chi phí (retention, cap/category)
- [ ] Kết luận + trả lời 3 câu tự kiểm tra của guide; 7+1 truy vấn Pha B

## Pha E — Ghi chép + cuối phiên

- [ ] `evidence/M11.md` (mới): phần dashboard + log (3 dòng đầu của M11); ô cảnh báo ghi "D22"
- [ ] `notes/d21.md` (quyết định, số đo, kế hoạch nói sai) · plan: tick D21 + Recovery + Tiến độ · `known-issues.md`
- [ ] Cuối phiên: capacity 1, không script nào chạy; nhắc chi phí (ingest mới). **Không** đề xuất `make down` (người dùng 28/09: tạm thời không tắt môi trường)

---

## Bảng bẫy

| # | Bẫy | Hậu quả | Tránh |
|---|---|---|---|
| T1 | Quên diagnostic setting cho slot staging | Staging câm; sau swap vẫn có log (setting gắn slot) nhưng không so được trước/sau | A1 `for_each` 4 bề mặt |
| T2 | Đẩy `AllMetrics` vào workspace | Nhân đôi metric, ăn cap 0,2 GB | Quyết định B |
| T3 | Chạy `m2-poll.sh`/test tải dài sau khi bật `HTTPLogs` | ~300–400 MB/ngày → chạm cap → **mất log đúng lúc demo** | Poll ngắn; đo A5 trước; cân nhắc nâng cap tạm (hỏi người dùng — giới hạn chi phí) |
| T4 | Import/sửa `obs-poc` vào Terraform | Đụng hạ tầng của repo khác | Tên riêng `diag-vsf`; không `import` |
| T5 | `uuid()` cho tên Workbook | Mỗi `plan` đòi thay Workbook | `uuidv5` từ chuỗi cố định |
| T6 | Để resource ID/subscription id cứng trong JSON Workbook | Workbook gãy sau `make up` (suffix mới) và lộ subscription id vào repo | `templatefile` + biến |
| T7 | Dựng dashboard trên App Insights | Trái M11 | Workbook `source_id = "azure monitor"`; App Insights chỉ ở ô trace |
| T8 | `make down` khi PoC còn chạy trên plan | Destroy gãy giữa chừng, môi trường dở dang | `known-issues.md` #23 — gỡ PoC trước |
| T9 | Chụp Workbook/Logs có IP thật của người dùng (Q7) hoặc email ở header | Lộ thông tin | Che 2 octet cuối IP; cắt header Portal |
| T10 | Dùng mốc phút của metric để ghép timeline | Lệch 1–2 phút (D19) | Ghép bằng log/Activity Log |

## Ước lượng

| Pha | Thời gian | Tốn tiền |
|---|---|---|
| A — diagnostic settings | ~1 giờ | ingest (ước ~20–40 MB/ngày thêm lúc yên) |
| B — KQL | ~1,5 giờ | query 0 |
| C — Workbook | ~2 giờ | 0 |
| D — docs/logging.md | ~1 giờ | 0 |
| E — ghi chép | ~0,5 giờ | — |

Gộp A và C vào **một PR** nếu làm liền (giống D20 B+C) để chỉ tốn một lần CD swap — hỏi người dùng lúc đó.

## Lưu ý cho phiên có AI

- Kế hoạch do Claude Code (Opus 5.5) viết 2026-09-28 ngay sau D20; dữ kiện có lệnh chỉ đọc cùng ngày. Hai
  chỗ kế hoạch D20 sai (`ai-failure-log.md` #36–#37) — **kiểm lại** mọi câu "mặc định là …" với đúng bản đang cài.
- KQL qua CLI: script `az rest --resource https://api.loganalytics.io …/v1/workspaces/<customerId>/query` (chép
  từ `notes/d20.md`); không in customerId/subscription id vào repo.
- Claude in Chrome: menu thả xuống và tab trong iframe của Portal thường **không** nhận click (D19, D20) — mở blade
  bằng menu trái hoặc sửa `location.hash`; **không** chụp trang Overview của App Insights (hiện instrumentation key).
- Luật phiên: apply, merge (= CD swap), test tải phải hỏi. Lệnh `gh`/`az` chạy trần; script dài viết thành file.

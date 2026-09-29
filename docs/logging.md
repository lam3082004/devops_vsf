# Logging & monitoring — giải pháp, truy vấn, chi phí (D21, M11)

Guide: `docs/guides/d21-logging.md` · Nhật ký: `notes/d21.md` · Bằng chứng: `evidence/M11.md`.
Mọi số đo trong file này đo **2026-09-29** trên môi trường `jcip0s` (lệnh + kết quả thô ở `evidence/raw/d21-*`).

## 1. Luồng dữ liệu

```
be, fe (+ 2 slot staging) ── stdout JSON ──► AppServiceConsoleLogs ┐
        App Service front-end ─────────────► AppServiceHTTPLogs    │  diagnostic setting "diag-vsf"
        nền tảng (container start/stop) ───► AppServicePlatformLogs│  (infra/app/monitoring.tf)
        ip_restriction chặn (403) ─────────► AppServiceIPSecAuditLogs
MySQL slow log (≥ 1 s) ────────────────────► AzureDiagnostics (Category = MySqlSlowLogs)
be, fe OpenTelemetry ──► App Insights appi-vsf-<suffix> ──► AppRequests / AppDependencies / AppExceptions
                                                            ┘ tất cả trong CÙNG workspace log-vsf-<suffix>
Metric nền tảng (Web App, Plan, MySQL) ── KHÔNG vào workspace ── Workbook đọc thẳng Azure Monitor metrics
```

- **Metric ≠ log.** Metric là số đã gộp theo phút, lưu sẵn 93 ngày, đọc miễn phí, trễ 1–2 phút → dùng cho
  đường xu hướng (response time, request, CPU, connections). Log là từng dòng sự kiện, trả tiền theo GB, trễ
  2–15 phút → dùng để trả lời "chuyện gì đã xảy ra với request này" (lỗi gì, path nào, `trace_id` nào).
- **Failure rate không cần App Insights:** `AppServiceHTTPLogs` có `ScStatus` của **mọi** request do front-end
  App Service ghi — đếm `ScStatus >= 500` chia tổng là ra (Q2). Metric `Http5xx`/`Requests` của Web App cũng
  cho số 5xx mà không cần SDK nào trong app.

## 2. So sánh 3 giải pháp (guide §5)

Giá: Azure Retail Prices API, Central India, tra 2026-09-29 (`evidence/raw/d21-retail-prices-20260929.txt`).

| Tiêu chí | **Log Analytics + Workbook** (chọn) | Azure Managed Grafana (+ Azure Monitor/LA làm nguồn) | Tự dựng Loki + Grafana (VM) |
|---|---|---|---|
| Chi phí cố định | **$0** — Workbook miễn phí | Essential: **$6/user/tháng** · Standard: $0,04788/giờ/node (**≈ $35/tháng**) + $6/user | VM B2s $0,0448/giờ (**≈ $33/tháng**) + disk E6 64 GiB $5,28 + mount $0,66 ≈ **$39/tháng**, chạy 24/7 |
| Chi phí theo dữ liệu | $3,22/GB ingest (5 GB/tháng đầu miễn phí/billing account), retention 31 ngày đầu miễn phí | Như cột trái (Grafana chỉ đọc từ Azure Monitor/LA) | Disk + băng thông; ingest không tính tiền nhưng phải tự đẩy log (Promtail/Alloy/OTel collector) |
| Công vận hành | Thấp — không có máy nào để vá | Thấp–vừa (user, datasource, quyền MI) | **Cao**: vá OS, nâng cấp Loki/Grafana, backup, TLS, auth, giám sát chính nó |
| Ngôn ngữ truy vấn | KQL | KQL qua datasource + PromQL/LogQL nếu thêm nguồn khác | LogQL (+ PromQL nếu có Prometheus) |
| Tích hợp Azure | Sẵn (diagnostic settings, metric, alert, Resource Graph) | Tốt (datasource Azure Monitor dựng sẵn) | Phải tự đẩy log; metric Azure qua plugin |
| Nguồn ngoài Azure | Hạn chế | Tốt | Tốt |
| Terraform hoá | Được — đã làm (`azurerm_application_insights_workbook`) | Được (`azurerm_dashboard_grafana` + provider grafana cho dashboard) | Được, nhiều thứ hơn hẳn (VM, NSG, disk, cloud-init, cấu hình Loki) |
| Alert | Azure Monitor alert (đã làm D22) | Grafana alerting hoặc Azure Monitor | Grafana/Loki ruler — tự dựng đường gửi email |
| Hợp với bài này | ✅ | Quá mức cần — trả tiền cố định cho đúng thứ Workbook làm được | Quá mức cần — gấp ~20 lần tiền ingest thực tế, thêm một hệ thống phải trực |

**Kết luận:** Log Analytics + Workbook. Ingest thực tế ~0,05–0,1 GB/ngày (mục 4) → nằm trong 5 GB/tháng miễn phí
hoặc vài chục cent/tháng; hai phương án còn lại có chi phí **cố định** $6–39/tháng trước khi có dòng log nào, và
lợi thế của chúng (nhiều nguồn ngoài Azure, LogQL/PromQL) bài này không dùng. Chuyển sang Managed Grafana khi có
nhiều nguồn ngoài Azure hoặc nhiều người xem dashboard hơn số người có quyền Azure.

## 3. Truy vấn KQL (Q1–Q8)

Chạy 2026-09-29 qua Log Analytics query API (chỉ đọc), cửa sổ 3 giờ gồm cả drill `/boom` (06:42:59–06:51:00Z).
Kết quả thô đầy đủ: `evidence/raw/d21-kql-20260929.tsv`. Trong Workbook, các truy vấn này nhận khoảng thời gian từ
tham số `TimeRange` (bỏ dòng `where TimeGenerated > ago(…)`).

Quy ước chung: `_ResourceId has "/sites/" and _ResourceId !has "/slots/"` = chỉ 2 site production;
`app = tostring(split(_ResourceId, "/")[8])` = tên site (`app-vsf-…` = be, `fe-vsf-…` = fe).

### Q1 — request rate theo 5 phút (không tính probe)

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(3h)
| where _ResourceId has "/sites/" and _ResourceId !has "/slots/"
| where CsUriStem !in ("/health", "/version", "/api/version")
| extend app = tostring(split(_ResourceId, "/")[8])
| summarize requests = count() by bin(TimeGenerated, 5m), app
```

Kết quả: `be` 61 → 127 → 30 request trong 3 khung 06:40/06:45/06:50 (drill), 5 ở khung 06:35; `fe` 1–4.
**Kết luận:** thấy rõ đợt drill; probe bị loại nên con số là traffic thật.

### Q2 — failure rate (% 5xx) theo 5 phút

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(3h)
| where _ResourceId has "/sites/" and _ResourceId !has "/slots/"
| where CsUriStem !in ("/health", "/version", "/api/version")
| extend app = tostring(split(_ResourceId, "/")[8])
| summarize total = count(), errors_5xx = countif(ScStatus >= 500) by bin(TimeGenerated, 5m), app
| extend fail_pct = round(100.0 * errors_5xx / total, 2)
```

Kết quả: `be` **81,97% · 96,06% · 83,33%** (06:40 · 06:45 · 06:50), 0% các khung khác; `fe` 0%.
**Kết luận:** failure rate lấy được **chỉ từ log nền tảng**, không cần App Insights — alert 5xx (D22) dùng đúng bảng này.

### Q3 — p50/p95 thời gian xử lý theo path

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(3h)
| where _ResourceId has "/sites/" and _ResourceId !has "/slots/"
| extend app = tostring(split(_ResourceId, "/")[8])
| summarize requests = count(), p50_ms = percentile(TimeTaken, 50), p95_ms = percentile(TimeTaken, 95) by app, CsUriStem
| order by p95_ms desc
```

Kết quả (ms): `fe /` p50 234 · p95 581 · `be /items` 156 · **520** (117 request) · `be /stats` 342 · `be /health` 102 · 136 ·
`be /boom` 1 · 3. **Kết luận:** chậm nhất là trang `fe /` và `be /items` — khớp trace: mỗi lệnh SQL ~50 ms vì MySQL
khác vùng (`known-issues.md` #27). `TimeTaken` tính bằng ms, `CsUriStem` không có query string.

### Q4 — parse log JSON của app

```kusto
AppServiceConsoleLogs
| where TimeGenerated > ago(3h)
| extend app = tostring(split(_ResourceId, "/")[8])
| extend log = parse_json(ResultDescription)
| where isnotempty(log.event)
| project TimeGenerated, app, level = tostring(log.level), event = tostring(log.event), path = tostring(log.path),
          status = toint(log.status), duration_ms = tolong(log.duration_ms), trace_id = tostring(log.trace_id)
```

Kết quả: mỗi request của `be` một dòng `event=request` có `path`, `status`, `duration_ms`, `trace_id` (ví dụ
`/items 200 506 ms`). **Kết luận:** log 1 dòng JSON (D4) parse thẳng được; tên field theo
`app/be/Infrastructure/JsonConsoleLogger.cs` (`time`, `level`, `message` + field riêng).

### Q5 — top lỗi (level = error, hoặc request ≥ 500)

```kusto
AppServiceConsoleLogs
| where TimeGenerated > ago(3h)
| extend app = tostring(split(_ResourceId, "/")[8])
| extend log = parse_json(ResultDescription)
| where tostring(log.level) == "error" or toint(log.status) >= 500
| summarize count_ = count(), last_seen = max(TimeGenerated), sample_trace_id = take_any(tostring(log.trace_id))
    by app, level = tostring(log.level), event = tostring(log.event), path = tostring(log.path), error = tostring(log.error)
| order by count_ desc
```

Kết quả: `error boom intentional_failure` **197** + `request /boom` (status 500) **197**, `sample_trace_id` có giá trị ở
dòng `request`. **Kết luận:** dòng lỗi cho biết *lỗi gì*; `trace_id` nằm ở dòng `request` cùng request — vì vậy lọc
`level == "error" or status >= 500` chứ không chỉ `level == "error"`. (App không log stack trace ra stdout; stack
nằm ở `AppExceptions` qua trace — Q8/runbook bước 3.)

### Q6 — container start/stop (PlatformLogs)

```kusto
AppServicePlatformLogs
| where TimeGenerated > ago(3h)
| extend app = tostring(split(_ResourceId, "/")[8]), slot = iff(_ResourceId has "/slots/", "staging", "production")
| where Message has_any ("Starting container", "started", "Stopping", "stopped", "Pulling image", "Container start", "site started", "terminated")
| project TimeGenerated, app, slot, Level, Message
```

Kết quả: 06:17:43–06:18:03Z `fe` staging `Stopping container … Container is terminated … Site … stopped` rồi khởi động
lại — đúng lúc apply PR #65 thêm app setting cho `fe`. **Kết luận:** mỗi lần đổi app setting/swap để lại dấu vết
restart ở đây — nguồn để ghép timeline sự cố (thay cho mốc phút của metric, bẫy T10).

### Q7 — IP bị chặn (IPSecAuditLogs, che 2 octet cuối)

```kusto
AppServiceIPSecAuditLogs
| where TimeGenerated > ago(3h)
| extend app = tostring(split(_ResourceId, "/")[8]), slot = iff(_ResourceId has "/slots/", "staging", "production")
| extend ip_masked = strcat(strcat_array(array_slice(split(CIp, "."), 0, 1), "."), ".x.x")
| summarize requests = count(), first_seen = min(TimeGenerated), last_seen = max(TimeGenerated) by app, slot, ip_masked, Result
```

Kết quả: chỉ có `Result = Allowed` — `104.30.x.x` (máy làm việc), `20.219.x.x` (outbound của `fe` gọi `be`),
`20.109.x.x` (runner CD, luật tạm D17). **Chưa có dòng `Denied`** trong cửa sổ đo: không có IP ngoài whitelist để thử
(`M6` đã đo 403 bằng mạng khác ở D13/D16). **Kết luận:** bảng này ghi **cả** request được cho qua → đủ để trả lời "ai
đang gọi vào" (M6 dạng log); lọc `Result != "Allowed"` khi tìm IP bị chặn.

### Q8 — nối trace (App Insights) ↔ log cùng request

```kusto
AppRequests
| where TimeGenerated > ago(3h)
| where Success == false
| project TimeGenerated, role = AppRoleName, request = Name, ResultCode, OperationId, Id
| join kind=inner (
    AppServiceConsoleLogs
    | where TimeGenerated > ago(3h)
    | extend log = parse_json(ResultDescription)
    | where isnotempty(log.span_id)
    | project trace_id = tostring(log.trace_id), span_id = tostring(log.span_id), log_event = tostring(log.event),
              log_path = tostring(log.path), log_status = toint(log.status), log_duration_ms = tolong(log.duration_ms)
  ) on $left.OperationId == $right.trace_id, $left.Id == $right.span_id
```

Kết quả: mỗi `GET boom 500` trong `AppRequests` khớp **đúng 1** dòng log `request /boom 500` (10/10 dòng mẫu).
**Kết luận:** khoá nối là **`trace_id` + `span_id`**, không chỉ `trace_id` — health checker của App Service gửi
`traceparent` cố định nên join theo `trace_id` một mình ghép nhầm một request với hàng loạt dòng `/health`
(`known-issues.md` #29, đo 29/09).

## 4. Chi phí đo thật + nút vặn

Đo 2026-09-29 trên workspace `log-vsf-jcip0s`:

| Nguồn | Khoảng yên 06:55–07:13Z (`estimate_data_size`) | Quy ra ngày |
|---|---|---|
| App Insights (`AppMetrics` 772 KB · `AppDependencies` 179 · `AppPerformanceCounters` 150 · `AppTraces` 56 · `AppRequests` 45) | 1 202 KB / 18 phút | ~94 MB |
| Log D21 (`AppServiceConsoleLogs` 65 KB · `AppServiceHTTPLogs` 33 · `AppServiceIPSecAuditLogs` 26) | 124 KB / 18 phút | ~10 MB |
| MySQL slow log (≥ 1 s) | 0 dòng | ~0 |
| **Tổng** | 1 325 KB / 18 phút | **~0,1 GB/ngày** |

Bảng `Usage` (số tính tiền, 24 giờ tới 07:00Z): `AppMetrics` 39 MB · `AppDependencies` 8,9 · `AppPerformanceCounters`
6,4 · `AppTraces` 2,7 · `AppRequests` 2,7 · `AzureDiagnostics` 0,05 — bảng này trễ vài giờ nên chưa có các bảng
App Service mới.

- **Chi phí:** ~0,1 GB/ngày ≈ 3 GB/tháng → nằm trong **5 GB/tháng miễn phí** → ~$0; nếu hết phần miễn phí: 3 × $3,22 ≈
  **$9,7/tháng**. Retention 30 ngày ≤ 31 ngày miễn phí → $0. Alert D22 ≈ $1,70/tháng. Workbook $0.
- **Cap 0,2 GB/ngày:** lúc yên dùng ~50%. Drill `/boom` 8 phút + deploy thêm vài MB. Poll 1 giây/lần cả ngày
  (`scripts/m2-poll.sh`) mới là rủi ro chạm cap (bẫy T3 `notes/d21-prep.md`) — probe đã được loại khỏi trace ở cả
  `be` và `fe`, nhưng `AppServiceHTTPLogs` vẫn ghi mọi request.
- **Nút vặn lớn nhất hiện tại:** `AppMetrics` = **58%** ingest — metric chuẩn distro .NET của `be` tự gửi, trùng với
  metric nền tảng Workbook đang đọc. Chưa kiểm distro .NET có tuỳ chọn tắt riêng phần này
  hay phải lọc meter/View — ghi lại để quyết khi ingest thành vấn đề (bản `fe` không gửi metric nào: chỉ exporter trace).

## 5. Tự kiểm tra (guide D21)

1. **Metric và log khác nhau thế nào, ô nào dùng cái nào?** Mục 1. Workbook: hàng 1–3 + health = metric (xu
   hướng, rẻ, nhanh); failure %, p95 theo path, lỗi mới nhất, trace = log (chi tiết từng request).
2. **Vì sao failure rate lấy được mà không cần App Insights?** Mục 1 — `AppServiceHTTPLogs.ScStatus` do nền
   tảng ghi cho mọi request; metric `Http5xx` cũng vậy. Alert 5xx (D22) chạy trên chính bảng này.
3. **Hai nút vặn chi phí chính?** (1) **Lượng ingest** — chọn category (không `AllMetrics`, không audit log),
   lọc/sampling ở nguồn (probe không trace), `daily_quota_gb`; (2) **Retention** — 30 ngày (≤ 31 ngày miễn phí).

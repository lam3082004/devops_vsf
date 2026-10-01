## Agent đọc sự cố: rg-vsf-dev, 1 giờ gần nhất

Chạy lúc 2026-10-01T06:29:33Z · workspace `log-vsf-jcip0s` · danh tính: `7df24d2f-ae65-4a73-bf54-ea8576799156`

### 1. Alert (Fired trong 1 giờ, hoặc vẫn đang Fired)

| alert | sev | điều kiện | trạng thái | bắt đầu | resolved |
|---|---|---|---|---|---|
| 5xx rate > 5% (be/fe production) | Sev1 | Fired | New | 2026-10-01T06:27:39.4632372Z |  |

### 2. Tỉ lệ 5xx theo app (production, bỏ probe)

| app | total | errors_5xx | fail_pct |
|---|---|---|---|
| app-vsf-jcip0s | 748 | 29 | 3.88 |
| fe-vsf-jcip0s | 67 | 17 | 25.37 |

### 3. Endpoint lỗi nhiều nhất

| app | CsUriStem | ScStatus | errors | first_seen | last_seen |
|---|---|---|---|---|---|
| app-vsf-jcip0s | /items | 503 | 29 | 2026-10-01T06:12:05.203976Z | 2026-10-01T06:27:51.328036Z |
| fe-vsf-jcip0s | /api/health | 503 | 17 | 2026-10-01T06:19:49.456532Z | 2026-10-01T06:27:53.828816Z |

### 4. Lỗi trong log app (level=error hoặc status ≥ 500)

| app | event | path | error | count_ | last_seen | sample_trace_id |
|---|---|---|---|---|---|---|
| app-vsf-jcip0s | request | /items |  | 188 | 2026-10-01T06:28:56.179753Z | 06f2ba0599fea4d6702d2bde3a96d9a6 |
| app-vsf-jcip0s | db_error | /items | The operation was canceled. | 145 | 2026-10-01T06:28:56.1792778Z |  |
| app-vsf-jcip0s | request | /health |  | 47 | 2026-10-01T06:28:56.4039454Z | d3854ebd9bdf3fdef803ad7c80703bba |
| app-vsf-jcip0s | db_error | /items | Connect Timeout expired. | 43 | 2026-10-01T06:28:51.0761055Z |  |

### 5. Exception gần nhất (App Insights)

| AppRoleName | ExceptionType | method | count_ | last_seen | sample_operation_id |
|---|---|---|---|---|---|
| app-vsf-jcip0s | System.OperationCanceledException | System.Threading.CancellationToken.ThrowOperationCanceledException | 154 | 2026-10-01T06:29:41.3040182Z | 8543b0baf25f87b6558b8b7ce1ee28e6 |
| app-vsf-jcip0s | MySqlConnector.MySqlException | MySqlConnector.MySqlConnection.CreateSessionAsync | 44 | 2026-10-01T06:29:21.3485261Z | 9432f0b68d871bb75e3e5e8f2807ddf7 |

### 6. Container khởi động lại / dừng

| app | slot | events | last_seen |
|---|---|---|---|
| app-vsf-jcip0s | staging | 6 | 2026-10-01T05:30:02.2957404Z |
| app-vsf-jcip0s | production | 9 | 2026-10-01T06:20:17.1809161Z |
| fe-vsf-jcip0s | staging | 9 | 2026-10-01T05:31:13.3642275Z |
| fe-vsf-jcip0s | production | 6 | 2026-10-01T05:30:13.5528221Z |

### 7. Metric `Http5xx` (tổng theo app, 1 giờ)

| app | Http5xx | Requests |
|---|---|---|
| app-vsf-jcip0s | 60.0 | 890.0 |
| fe-vsf-jcip0s | 18.0 | 73.0 |

### Kết luận (luật cố định, không phải LLM)

- 48 response 5xx production · 1 alert đang Fired.
- Lấy `sample_trace_id` ở mục 4 hoặc `sample_operation_id` ở mục 5, tra tiếp theo runbook.md bước 3 (Workbook, mục trace).
- Agent **không** sửa gì. Mọi hành động phục hồi (apply, swap, restart) là việc của người trực theo runbook.md.

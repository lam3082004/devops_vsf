## Agent đọc sự cố: rg-vsf-dev, 1 giờ gần nhất

Chạy lúc 2026-10-01T07:03:57Z · workspace `log-vsf-jcip0s` · danh tính: `7df24d2f-ae65-4a73-bf54-ea8576799156`

### 1. Alert (Fired trong 1 giờ, hoặc vẫn đang Fired)

| alert | sev | điều kiện | trạng thái | bắt đầu | resolved |
|---|---|---|---|---|---|
| 5xx rate > 5% (be/fe production) | Sev1 | Fired | New | 2026-10-01T07:02:37.9469201Z |  |
| Failure Anomalies - appi-vsf-jcip0s | Sev3 | Fired | New | 2026-10-01T06:38:29.3521943Z |  |
| 5xx rate > 5% (be/fe production) | Sev1 | Resolved | New | 2026-10-01T06:27:39.4632372Z | 2026-10-01T06:53:44.0710537Z |

### 2. Tỉ lệ 5xx theo app (production, bỏ probe)

| app | total | errors_5xx | fail_pct |
|---|---|---|---|
| app-vsf-jcip0s | 1178 | 151 | 12.82 |
| fe-vsf-jcip0s | 128 | 23 | 17.97 |

### 3. Endpoint lỗi nhiều nhất

| app | CsUriStem | ScStatus | errors | first_seen | last_seen |
|---|---|---|---|---|---|
| app-vsf-jcip0s | /items | 503 | 151 | 2026-10-01T06:12:05.203976Z | 2026-10-01T07:02:59.02359Z |
| fe-vsf-jcip0s | /api/health | 503 | 23 | 2026-10-01T06:19:49.456532Z | 2026-10-01T06:30:53.558402Z |

### 4. Lỗi trong log app (level=error hoặc status ≥ 500)

| app | event | path | error | count_ | last_seen | sample_trace_id |
|---|---|---|---|---|---|---|
| app-vsf-jcip0s | request | /items |  | 288 | 2026-10-01T07:01:59.3014868Z | c3e33f142ca8adc856766f723162dc97 |
| app-vsf-jcip0s | db_error | /items | The operation was canceled. | 170 | 2026-10-01T06:31:01.53797Z |  |
| app-vsf-jcip0s | db_error | /items | Value cannot be null. (Parameter 's') | 71 | 2026-10-01T07:01:59.3014519Z |  |
| app-vsf-jcip0s | request | /health |  | 57 | 2026-10-01T06:30:56.4029884Z | f3d3bfca0ea5d478f2cd9f3e20c985dc |
| app-vsf-jcip0s | db_error | /items | Connect Timeout expired. | 47 | 2026-10-01T06:30:51.2469007Z |  |

### 5. Exception gần nhất (App Insights)

| AppRoleName | ExceptionType | method | count_ | last_seen | sample_operation_id |
|---|---|---|---|---|---|
| app-vsf-jcip0s | System.OperationCanceledException | System.Threading.CancellationToken.ThrowOperationCanceledException | 170 | 2026-10-01T06:31:01.5375057Z | 45db7795ddf55533fc080a41594e00ed |
| app-vsf-jcip0s | MySqlConnector.MySqlException | MySqlConnector.MySqlConnection.CreateSessionAsync | 47 | 2026-10-01T06:30:51.246209Z | c3e33f142ca8adc856766f723162dc97 |

### 6. Container khởi động lại / dừng

| app | slot | events | last_seen |
|---|---|---|---|
| app-vsf-jcip0s | production | 13 | 2026-10-01T07:00:22.9597098Z |
| fe-vsf-jcip0s | staging | 20 | 2026-10-01T07:03:11.3365474Z |
| app-vsf-jcip0s | staging | 23 | 2026-10-01T07:01:34.001599Z |

### 7. Metric `Http5xx` (tổng theo app, 1 giờ)

| app | Http5xx | Requests |
|---|---|---|
| app-vsf-jcip0s | 184.0 | 1488.0 |
| fe-vsf-jcip0s | 23.0 | 133.0 |

### Kết luận (luật cố định, không phải LLM)

- 174 response 5xx production · 2 alert đang Fired.
- Lấy `sample_trace_id` ở mục 4 hoặc `sample_operation_id` ở mục 5, tra tiếp theo runbook.md bước 3 (Workbook, mục trace).
- Agent **không** sửa gì. Mọi hành động phục hồi (apply, swap, restart) là việc của người trực theo runbook.md.

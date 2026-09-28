# Distributed tracing + exception `/boom` trong App Insights (D20)

Ngày: 2026-09-28 · Bài: D20 (`docs/guides/d20-cost-report-appinsights.md` mục 3) · Kế hoạch:
`notes/d20-prep.md` · Nhật ký: `notes/d20.md` · Code: PR #59 (`5a8d982`)
Môi trường: `rg-vsf-dev`, suffix `jcip0s` · `be` = `app-vsf-jcip0s` · workspace `log-vsf-jcip0s` ·
App Insights `appi-vsf-jcip0s` (workspace-based, **tạm** theo mặc định Q1 — `known-issues.md` #5)

> **TRẠNG THÁI: ĐẠT phần `be`.** Một request đi qua ba chỗ với **cùng một giá trị**:
> `X-Trace-Id` (header trả về) = `trace_id` (log JSON của container) = `OperationId` (App Insights), và
> `span_id` trong log = `Id` của dòng request. `/items` có span MySQL con; `/boom` có exception
> `BoomException` trong Failures. `fe` chưa phát span (quyết định G) — chặng `fe → be` là việc của D21.

## 1. Cấu hình (đọc lại từ Azure sau apply 07:44–07:47Z)

| Kiểm | Kết quả | Nguồn |
|---|---|---|
| `terraform apply` từ `main` `5a8d982` (plan `-out` → apply đúng file đó, xoá file plan) | 3 added (workspace, App Insights, secret), 2 changed (app setting `be` site + slot) | `evidence/raw/d20-apply-20260928.log` (subscription id đã che) |
| `terraform plan` ngay sau apply | **No changes** | `notes/d20.md` Pha D |
| Workspace | PerGB2018 · retention **30** ngày · daily cap **0,2 GB** | `az monitor log-analytics workspace show` |
| App Insights | `IngestionMode = LogAnalytics` (workspace-based) | `az resource show` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` trên `be` site **và** slot staging | Key Vault reference, **Resolved**, identity UserAssigned — không có giá trị plaintext trong app settings | `az rest …/config/configreferences/appsettings` |
| Log container sau restart | `{"event":"telemetry_enabled"}` lúc 07:46:35Z | `evidence/raw/d20-be-log-trace-20260928.jsonl` |

## 2. Một request, ba chỗ, một giá trị

Request gửi 07:49–07:51Z (`evidence/raw/d20-trace-requests.log`, 7 request có chủ đích, không phải test
tải). KQL chạy trên workspace (`evidence/raw/d20-kql-20260928.tsv`). Log container lấy bằng
`az webapp log tail` (`evidence/raw/d20-be-log-trace-20260928.jsonl`).

| Request | `X-Trace-Id` (header) | `trace_id` / `span_id` (log JSON) | `AppRequests` `OperationId` / `Id` | Span con |
|---|---|---|---|---|
| `GET /items` + `traceparent` tự tạo `00-6fc2396d…-155ce943…-01` | `6fc2396d4d0423d1b1f841b45623e25a` | `6fc2396d…e25a` / `c59a5d828425b844` | `6fc2396d…e25a` / `c59a5d828425b844` | 3 × MySQL (Open, Execute ×2), `ParentId = c59a5d82…` |
| `POST /items` (201) | `94a60ece181b231101da3b2f38e5e6e1` | — (không lấy log dòng này) | `94a60ece…e5e1` / `2c60fbcf92f08987` | 5 × MySQL (Open, Execute ×3, Commit) |
| `GET /boom` (500) | `91efddedb7fddf7cca38ed3a16ac7d24` | `91efdded…7d24` / `86591f7e372de4a5` | `91efdded…7d24` / `86591f7e372de4a5` | `AppExceptions`: `OpsBoard.Common.BoomException`, `ParentId = 86591f7e…` |
| `GET /items` lúc đang tail log | `57af4aa5653143ded103cc257bf5938e` | `57af4aa5…938e` / `e5e1c17ac991a9b5` | `57af4aa5…938e` / `e5e1c17ac991a9b5` | 3 × MySQL |

- `traceparent` do client gửi được **giữ nguyên** trace id — `fe` sau này chỉ cần chuyển tiếp header
  (`app/fe/src/lib/api.ts` đã làm) là chặng `fe → be` nối vào cùng trace.
- `/health` và `/version`: **0** dòng trong `AppRequests` từ lúc bật telemetry, dù health check của App
  Service gọi `/health` mỗi phút (quyết định E). Log JSON của chúng vẫn có `trace_id` như cũ.
- `AppTraces` chỉ có `read-result-set-header` (span event của MySqlConnector, exporter đổi thành dòng
  `traces`) — **không** có log của app: log vẫn chỉ đi JSON stdout (D21 đưa vào Log Analytics).
- Mỗi lệnh SQL ~50 ms — gần như toàn bộ là độ trễ **Central India ↔ Southeast Asia** (app và MySQL khác
  vùng, `known-issues.md` #6): `GET /items` 164 ms thì 3 lệnh SQL chiếm ~162 ms. Trace cho thấy thứ mà
  `HttpResponseTime` gộp (D19) không tách được.

## 3. Ảnh Portal

- `evidence/d20/screenshots/d20-appinsights-failures-boom-20260928-0755.png` — App Insights → **Failures**
  (Server, 24 giờ): `GET boom` 2/2 failed, **Top 3 exception types = `BoomException`**, response code 500.
  Hai dòng 404 còn lại là request vào `/` và `/robots933456.txt` (probe khởi động container của App Service →
  `MapFallback` 404).
- `evidence/d20/screenshots/d20-appinsights-e2e-items-20260928-0903.png` — **End-to-end transaction** của
  đúng `Operation ID 6fc2396d4d0423d1b1f841b45623e25a` (dòng đầu bảng mục 2): `GET items` 164,1 ms → Open 54,0 ms
  → Execute `SELECT COUNT(*)` 53,8 ms → Execute `SELECT … FROM tickets` 54,5 ms, xen 2 dòng trace
  `read-result-set-header`. Người dùng chụp tay 28/09 (blade không nhận click qua extension); header có email
  đã cắt, ô *Compute Resource Id* (chứa subscription id) đã che.

## 4. Hạn chế

- Chỉ `be`. `fe` không tạo span; trình duyệt không gửi `traceparent` nên hôm nay mỗi request `fe → be`
  bắt đầu một trace mới ở `be` (quyết định G, D21).
- App Insights là **tạm**: Q1 chưa có trả lời của mentor. `enable_app_insights = false` gỡ App Insights,
  secret và app setting; app tự tắt telemetry (`Infrastructure/Telemetry.cs`), workspace giữ lại cho D21.
- Sampling 100% (trừ probe): đúng với lưu lượng hiện tại. Đợt tải kiểu D19 (`/load`) sẽ sinh 1 trace mỗi
  request — ingest đo lại ở `notes/d20.md` D8.

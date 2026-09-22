# API spec — OpsBoard backend (.NET, `app/be`)

Liên quan: [prd](prd.md) · [database-schema](database-schema.md). Đây là hợp đồng thiết kế; code phải khớp,
lệch thì sửa file này cùng PR.

## Quy ước chung
- JSON, `snake_case`. Thời gian ISO-8601 UTC, luôn có hậu tố `Z` (`2026-09-21T14:02:00Z`). Mọi mốc thời gian
  lưu và trả về theo UTC; khi map `DateTime` đọc từ MySQL phải gán `DateTimeKind.Utc` trước khi serialize
  (MySqlConnector trả `DateTime` với `Kind=Unspecified`, không gán thì JSON thiếu hậu tố `Z`).
- Field `null` — hai quy tắc khác nhau tuỳ loại response:
  - `ErrorResponse`: field `null` bị **bỏ khỏi** response — `bad_request`/`not_found`/... chỉ có
    `reason` hoặc `detail` xuất hiện tuỳ loại lỗi.
  - `Ticket`, `Comment`, `Activity`, `/stats`: **luôn trả đủ field, kể cả khi giá trị là `null`** (ví dụ
    `assignee`, `resolved_at`, `from_value`) — dễ dùng cho frontend hơn field biến mất tuỳ dữ liệu.
  - Cài đặt (`Infrastructure/ApiSetup.cs`): mặc định toàn cục là `DefaultIgnoreCondition = Never`, và
    `ErrorResponse` tự mang `[property: JsonIgnore(WhenWritingNull)]` trên `Reason`/`Detail`. Đảo chiều như vậy
    thì DTO dữ liệu thêm về sau mặc định đã đúng, không ai phải nhớ gắn attribute.
- Header `X-User-Name` (1–50 ký tự): **bắt buộc với mọi thao tác ghi** (POST/PATCH). Thiếu → `400 bad_request`.
- Header `traceparent` (W3C) được nhận và chuyển tiếp; response luôn có `X-Trace-Id`. Giá trị lấy từ
  `TraceIdMiddleware`: ưu tiên `Activity.Current?.TraceId`, **nếu null** thì lấy trace-id từ header `traceparent` do frontend gửi, cuối cùng mới sinh ngẫu nhiên. (`Activity.Current` chỉ có khi có listener; app gọi `Logging.ClearProviders()` nên bình thường là null — xem `ai-failure-log.md` #12.) Nhờ vậy `trace_id` trong
  log JSON và header `X-Trace-Id` làm được ngay ở bước viết app này. OpenTelemetry (D20) chỉ thêm exporter để
  trace chạy tới Azure (App Insights), không phải điều kiện để có `trace_id`.
- Lỗi luôn theo dạng `ErrorResponse`:
```json
{ "error": "bad_request", "reason": "'title' khong duoc rong" }
```

| HTTP | `error` | Khi nào |
|---|---|---|
| 400 | `bad_request` | Input sai/thiếu; `reason` nói rõ |
| 404 | `not_found` | Không có ticket / route |
| 409 | `invalid_transition` | Chuyển trạng thái không hợp lệ (PRD mục 2) |
| 500 | `boom` | Chỉ `/boom` (lỗi cố ý, xem bảng endpoint hạ tầng) |
| 503 | `database_unavailable` | Mọi exception chưa xử lý từ action của `/items*`, `/stats` — xem giải thích dưới |
| 503 | — (`HealthResponse`, không phải `ErrorResponse`) | `/health` khi DB lỗi |

Vì sao **503** chứ không phải **500** cho lỗi không lường trước: `DatabaseExceptionFilter` bắt mọi exception
chưa xử lý từ action controller. Trong app này, repository (chạm MySQL) là nơi duy nhất có thể ném lỗi ngoài
dự kiến, nên bắt rộng và coi đó là "dịch vụ tạm thời không dùng được, thử lại sau" (503) hợp lý hơn "lỗi máy
chủ chung chung" (500) — không có mã lỗi `internal`; `500` chỉ còn dành riêng cho `/boom` (lỗi cố ý).

## Kiểu dùng chung
- `severity`: `low|medium|high|critical` · `category`: `infra|app|database|network|security|other`
- `status`: `open|in_progress|resolved|closed`

```json
// Ticket
{ "id": 41, "title": "MySQL hết kết nối", "description": "…", "severity": "critical",
  "category": "database", "status": "open", "reporter": "Nam", "assignee": null,
  "created_at": "2026-09-21T13:50:00Z", "updated_at": "2026-09-21T13:50:00Z", "resolved_at": null }
```

## Endpoint hạ tầng (hợp đồng theo topic.md — không đổi)
| Method | Path | Response |
|---|---|---|
| GET | `/health` | `200 {"status":"ok","db":"ok"}` · `503 {"status":"degraded","db":"error"}` |
| GET | `/version` | `200 {"sha":"<git sha>"}` |
| GET | `/load?seconds=n` | `200 {"burned_seconds":n,"iterations":…}` · `400` nếu n ngoài `1..LOAD_MAX_SECONDS` |
| GET | `/boom` | `500 {"error":"boom","detail":"…"}`, log level error, tiến trình sống tiếp |

## Ticket — `/items`

### `GET /items`
Query (đều tuỳ chọn): `status`, `severity`, `category`, `assignee`, `unassigned=true` (chưa phân công),
`q` (tìm trong title, tối đa 100 ký tự), `limit` (mặc định 20, tối đa 100), `offset` (mặc định 0).
Sắp xếp `updated_at` giảm dần.
```json
200 { "items": [ Ticket, … ], "total": 57, "limit": 20, "offset": 0 }
```
Giá trị lọc không hợp lệ → `400`.

- **`unassigned=true`**: lọc ticket chưa có người xử lý (`assignee IS NULL`). Không dùng `assignee=` rỗng vì
  dễ nhầm với "không lọc". `unassigned=true` và `assignee=<tên>` **không được dùng cùng lúc** → `400 bad_request`.
- **`q`**: khớp `LIKE '%…%'` trên `title`, tham số hoá; ký tự `%`, `_`, `\` trong chuỗi người dùng nhập phải
  được **escape** trước khi ghép vào pattern (nếu không, người dùng gõ `%`/`_` sẽ tự tạo wildcard ngoài ý muốn).
  Tối đa 100 ký tự, dài hơn → `400`.
- **`limit`**: gửi vượt quá 100 → `400 bad_request` (từ chối, **không** tự kẹp về 100) — nhất quán với cách xử lý
  `q` quá dài ở trên, để không âm thầm đổi ý client.

#### Cách frontend dựng kanban (S2, `wire-frame.md`)
Không có endpoint nhóm theo status. Frontend gọi **`GET /items` 4 lần song song**, mỗi lần
`?status=<open|in_progress|resolved|closed>&limit=20`; số đếm hiển thị trên mỗi cột lấy từ `total` của
chính response đó (không phải `items.length`). Cột `Closed` chỉ hiện 20 thẻ mới nhất vì cùng `limit=20`;
nút "xem tất cả" điều hướng sang danh sách (S3) với `status=closed`. Không thêm endpoint mới cho việc này.

### `POST /items`
```json
// request
{ "title": "MySQL hết kết nối", "description": "…", "severity": "critical",
  "category": "database", "assignee": "Lâm" }
// 201 → Ticket (status = open, reporter = X-User-Name)
```
Chỉ `title` bắt buộc. Ghi 1 dòng lịch sử `created`.

### `GET /items/{id}`
`200 { "ticket": Ticket, "activities": [Activity, …] }` (Activity theo thời gian tăng dần) · `404`.

Trang chi tiết ticket (S5, `wire-frame.md`) cần **hai lời gọi riêng**, không gộp:
`GET /items/{id}` (ticket + lịch sử) **và** `GET /items/{id}/comments` (bình luận).

### `PATCH /items/{id}`
Sửa một phần: `title`, `description`, `severity`, `category`, `assignee` (`null` = bỏ phân công).
Không sửa được `status` ở đây. Ghi lịch sử cho trường nào đổi. `200 Ticket` · `400` · `404`.

Body có field `status` (dù giá trị gì, kể cả `null`) → `400 bad_request` với `reason` gợi ý dùng
`PATCH /items/{id}/status` — tránh im lặng bỏ qua khiến client tưởng đổi được status trong khi thực
tế không đổi gì.

**Field vắng mặt vs field gửi `null`** (áp dụng cho `assignee` và `description`, hai field cho phép rỗng):
**vắng mặt trong JSON body = không đổi**; **gửi `null` = xoá giá trị hiện tại**. Cài đặt gợi ý ở .NET: khai
báo property kiểu `JsonElement` **KHÔNG nullable** (không phải `JsonElement?`) — vắng mặt trong body thì
System.Text.Json gán `default(JsonElement)`, có `ValueKind == JsonValueKind.Undefined`; gửi `null` trong JSON
thì `ValueKind == JsonValueKind.Null`; có giá trị thì `ValueKind` là kiểu thật (`String`, …). Dùng `string?`
thường thì hai trường hợp vắng mặt/null không phân biệt được (cả hai đều `null`). **Lưu ý (ai-failure-log #15):
`JsonElement?` (`Nullable<JsonElement>`) KHÔNG dùng được cho việc này** dù nghe hợp lý — `NullableConverter`
bọc ngoài tự chặn token JSON `null` và trả thẳng C# `null` trước khi converter thật của `JsonElement` chạy,
nên cả hai trường hợp đều cho `HasValue == false`, không phân biệt được. Phải dùng `JsonElement` trần.

### `PATCH /items/{id}/status`
```json
{ "status": "in_progress" }
```
`200 Ticket` · `409 invalid_transition` (kèm `reason`: "open -> resolved khong hop le") · `404`.
Cùng trạng thái hiện tại → `409`. Xem hiệu ứng phụ ở PRD mục 2.

### Comment — `/items/{id}/comments`
- `GET` → `200 { "comments": [Comment, …] }` (tăng dần theo thời gian) · `404`
- `POST` `{ "body": "…" }` → `201 Comment` · `400` · `404`
```json
// Comment
{ "id": 7, "ticket_id": 41, "author": "Lâm", "body": "Đang xem connection pool", "created_at": "…" }
```

### Activity
```json
{ "id": 12, "ticket_id": 41, "actor": "Lâm", "action": "status_changed",
  "from_value": "open", "to_value": "in_progress", "created_at": "…" }
```
`action`: `created` · `status_changed` · `assignee_changed` · `severity_changed` · `category_changed` ·
`title_changed` · `description_changed`. Ghi lịch sử cho **mọi trường thay đổi**, không chỉ
status/assignee/severity (xem thêm `prd.md` mục 2).

`from_value`/`to_value` là `VARCHAR(200)` (xem `database-schema.md`), không đủ cho `description` (tới 5000
ký tự). Với action `title_changed` và `description_changed`: `from_value`/`to_value` luôn để **`null`** —
lịch sử chỉ ghi nhận "đã đổi", không lưu nội dung cũ/mới. Các action còn lại (`status_changed`,
`assignee_changed`, `severity_changed`, `category_changed`) ghi giá trị thật vì đều ngắn.

## `GET /stats`
```json
200 { "total": 57,
      "by_status":   { "open": 4, "in_progress": 2, "resolved": 1, "closed": 50 },
      "by_severity": { "low": 20, "medium": 25, "high": 9, "critical": 3 },
      "open_critical": 3,
      "avg_resolution_minutes": 252 }
```
`avg_resolution_minutes` là `null` khi chưa có ticket nào `resolved`.

## Điểm cắm Jev (nội bộ, chưa có endpoint công khai)
Khi tạo ticket mà client không gửi `severity`/`category`, service gọi `TriageProvider`
(bản luật ban đầu). Trả về `{ severity, category, confidence }`; lỗi/timeout → mặc định `medium`/`other`.

## Ví dụ
```
curl -H 'X-User-Name: Lâm' -H 'Content-Type: application/json' \
  -d '{"title":"API chậm","severity":"high"}' https://<host>/items
curl -X PATCH -H 'X-User-Name: Lâm' -H 'Content-Type: application/json' \
  -d '{"status":"in_progress"}' https://<host>/items/41/status
```

## Khác biệt so với code hiện tại (việc cần làm)
Code hiện có (`app/be`) `/items` cho bảng `nodes` (`name`, `address`, `role`). Frontend (`app/fe`) mới là khung trống, chưa gọi API nào. Toàn bộ ticket, comment, activity, `/stats`,
`PATCH`, header `X-User-Name` và `X-Trace-Id` là **mới**.

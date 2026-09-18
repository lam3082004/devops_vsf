# Chuyển app từ Rust sang C#/.NET — 2026-09-18

Yêu cầu: đổi ngôn ngữ app sang C#/.NET, giữ nguyên logic (endpoint, log, config,
graceful shutdown, validate). Thực hiện trên nhánh `feat/dotnet-rewrite`, sau D8
(AI được sinh code từ D7, khai ở PR).

## Stack

| | Rust (D4–D5) | .NET (bản mới) |
|---|---|---|
| Framework | axum + tokio, router 1 file | ASP.NET Core MVC (Controllers), **.NET 10** |
| Kiến trúc | 1 module `http.rs` gộp route + handler | **Controller → Service → Repository**, mỗi lớp 1 interface, DI qua constructor (xem bên dưới) |
| DB driver | sqlx (raw SQL) | MySqlConnector (ADO.NET, raw SQL) — không dùng EF: giữ đúng các câu SQL gốc, không qua ORM/migration |
| Log | tracing_subscriber `.json().flatten_event(true)` | `IAppLogger`/`JsonConsoleLogger` (`System.Text.Json.Nodes`) — DI-injected, in thẳng 1 dòng JSON/record, không dùng `ILogger` mặc định (nó ghi multi-line/scope, không phẳng) |
| SHA lúc build | `build.rs` + `option_env!` | MSBuild Target `EmbedGitSha` (`NodeRegistry.csproj`) sinh `GitSha.g.cs` trước `CoreCompile`, bọc qua `AppMetadata` để controller không đụng thẳng vào code sinh tự động |
| Test | `#[cfg(test)]` cùng file | dự án riêng `app.Tests/` (xUnit) — .NET không có tương đương cfg(test) inline |
| JSON field | serde, field đã là snake_case | `JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower` + `DefaultIgnoreCondition = WhenWritingNull` (áp cho cả MVC và fallback 404, cả app thật lẫn test) để giữ đúng hợp đồng cũ: `id`, `last_seen_at`, `burned_seconds`, không lòi field null |

## Kiến trúc (theo yêu cầu: OOP Controller/Service/Repository)

```
Controllers/   HealthController, ItemsController, VersionController,
               LoadController, BoomController — chỉ nhận request, gọi
               đúng 1 service, map Result/bool sang HTTP status. Không
               có logic nghiệp vụ ở đây.
Services/      INodeService, IHealthService, ILoadService — nghiệp vụ
               (validate, chính sách timeout, đốt CPU). Trả Common.Result<T>
               cho lỗi "dự kiến" (400), KHÔNG throw cho những lỗi controller
               phải tự xử lý bằng response bình thường.
Repositories/  INodeRepository, IDatabaseRepository — CHỈ truy cập dữ liệu,
               không validate, không quyết định response. Lỗi DB ném thẳng
               exception nguyên bản của MySqlConnector.
Validation/    NodeRequestValidator — hàm thuần, tách khỏi NodeService để
               test được mà không cần dựng DI/DB.
Filters/       DatabaseExceptionFilter (IExceptionFilter) — bắt exception từ
               action, biến thành 503 database_unavailable + log 1 chỗ, thay
               vì try/catch lặp lại ở từng controller (đây là chỗ tập trung
               tương đương hàm `db_error()` cũ của bản Rust).
Middleware/    RequestLoggingMiddleware — 1 dòng JSON/request (method, path,
               status, duration_ms, request_id), đăng ký qua UseMiddleware<T>.
Contracts/     DTO trả ra ngoài (ErrorResponse, HealthResponse...) — tách
               khỏi Models (entity) để đổi hợp đồng API không kéo theo đổi
               entity.
Models/        Node (entity), RegisterNodeRequest (input thô), ValidationError.
Infrastructure/Config, IAppLogger/JsonConsoleLogger, MySqlDataSourceFactory —
               những thứ mọi lớp trên đều có thể cần.
Common/        Result<T> — kiểu kết quả có thể thất bại dự kiến, dùng ở tầng
               Service (khác exception, dùng cho lỗi hạ tầng bất ngờ).
```

Đăng ký DI trong `Program.cs`: `Config`, `IAppLogger`, `AppMetadata`,
`MySqlDataSource` là **singleton** (1 instance sống suốt vòng đời app);
Repository/Service là **scoped** (1 instance/request — quy ước chuẩn ASP.NET
Core dù ở đây không có state per-request thật sự cần tới).

**Bẫy đã gặp khi viết `app.Tests/HttpTests.cs`:** `AddControllers()` mặc định
chỉ quét controller trong **entry assembly** của host. Test host dựng trong
`app.Tests` nên entry assembly là `app.Tests`, không thấy controller nằm
trong `NodeRegistry.dll` → mọi route trả 404 dù logic đúng. Sửa bằng
`.AddApplicationPart(typeof(HealthController).Assembly)`. Không xảy ra ở
`Program.cs` thật vì ở đó `NodeRegistry` chính là entry assembly.

## Quyết định image — KHÔNG đạt lại 0 CVE như bản Rust

Bản Rust dùng musl + `scratch` → static binary, 0 CVE tuyệt đối (D5). .NET publish
kiểu framework-dependent vẫn cần runtime ASP.NET Core bên trong image nên
**không thể xuống tới `scratch`**. Hai lựa chọn cân nhắc:

1. **Native AOT + `runtime-deps` chiseled** — gần bằng Rust nhất (binary tĩnh hơn),
   nhưng minimal API + Native AOT bắt buộc `JsonSerializerContext` nguồn sinh
   cho MỌI kiểu JSON trả về (không được dùng object ẩn danh `new { ... }` như
   code hiện tại) — đổi kiến trúc nhiều, rủi ro lỗi cao hơn giá trị mang lại
   cho một app nội bộ nhỏ.
2. **Framework-dependent + `aspnet:10.0-noble-chiseled`** (đã chọn) — image
   "chiseled" chính thức của Microsoft: không shell, không apt, non-root sẵn.
   Không tĩnh hoàn toàn như Rust nên không đạt 0 CVE tuyệt đối — **xác nhận
   bằng Trivy thật, xem bên dưới**.

### Kết quả Trivy thật (2026-09-18, sau khi có quyền Docker)

`docker build` (framework-dependent, `-p:GitSha=$(git rev-parse --short HEAD)`)
→ image `182 MB` disk / `55.6 MB` content (so với **5.2 MB** của bản Rust
scratch+musl — đúng như dự đoán, không tĩnh hoàn toàn).

`trivy image --severity CRITICAL,HIGH,MEDIUM,LOW`:

| | Số lượng |
|---|---|
| CRITICAL / HIGH | **0 / 0** |
| MEDIUM | 7 (tất cả ở `libc6`/glibc, base image Ubuntu 24.04 của chiseled) |
| LOW | 0 |
| Với `--ignore-unfixed` | 6 (1 CVE chưa có bản vá bị loại) |
| App layer (.NET, `dotnet-core` scanner) | **0** ở cả 3 file `.deps.json` |

**Kết luận M9 cho bản .NET:** không đạt 0 CVE tuyệt đối như Rust, nhưng
**0 CRITICAL/HIGH** và chỉ 7 MEDIUM, toàn bộ ở glibc của base image (không
phải code/dependency .NET) — 6/7 đã có bản vá (`2.39-0ubuntu8.9`, base image
hiện đóng ở `.8`), sẽ tự hết khi Microsoft cập nhật base `noble-chiseled`.
Không cần `--ignore-unfixed` để "gian lận" đạt 0 — số liệu trung thực là 7 MEDIUM
đã có sẵn khi không dùng cờ đó. Trả lời được câu hỏi Q4 theo hướng: **không cần
`--ignore-unfixed`** cho bản .NET vì không có CRITICAL/HIGH để phải loại trừ.

### Kiểm chứng container thật (không còn chỉ chạy binary trần)

`docker run` + curl từng endpoint qua cổng thật:

| Kiểm tra | Kết quả |
|---|---|
| User trong container | uid **1654** (không phải root) — image chiseled không có `id`/shell nên `docker exec id` tự thất bại, xác nhận bằng `docker inspect --format '{{.Config.User}}'` thay vì exec |
| `/version` | 200, SHA đúng bằng `git rev-parse --short HEAD` lúc build |
| `/health` (DB chết) | 503 |
| `POST /items` (DB chết) | 503 `database_unavailable`, container không crash |
| 404 | JSON `not_found` |
| `docker stop -t 15` giữa lúc `/load?seconds=3` đang chạy | log `shutdown_started` ngay lúc nhận SIGTERM → **response vẫn đợi đủ ~3s, trả 200** → `shutdown_complete` sau đó, container thoát sạch — đúng hành vi graceful shutdown, xác nhận `ENTRYPOINT ["dotnet","NodeRegistry.dll"]` đúng là PID 1 nhận được tín hiệu |

## Đã kiểm chứng (không cần Docker, chạy binary Release trực tiếp)

Publish Release cục bộ (`dotnet publish -p:GitSha=e2e-test`), set biến môi
trường trỏ tới MySQL không tồn tại, chạy binary thật, gọi từng endpoint:

| Kịch bản (đối chiếu 7 kịch bản D4) | Kết quả |
|---|---|
| Thiếu `DB_PASSWORD` | log `config_error` (chỉ tên biến), **exit 1** |
| DB không kết nối được lúc khởi động | log `schema_failed` (warn, không chết), app vẫn `listening` |
| `/health` khi DB chết | **503** `{"status":"degraded","db":"error"}` |
| `/version` | 200, đúng SHA nhúng lúc `publish -p:GitSha=...` |
| `/load` thiếu/`abc`/`0`/`6` (max=5) | 400 `bad_request` đúng lý do |
| `/load?seconds=1` | 200, `iterations` > 0, mất đúng ~1.0s |
| `/boom` | 500, request `/version` ngay sau vẫn 200 |
| path lạ | 404 JSON `not_found` |
| `POST /items` khi DB chết | 503 `database_unavailable` (không crash) |
| **SIGTERM giữa lúc `/load?seconds=3` đang chạy** | log `shutdown_started` ngay khi nhận tín hiệu → **response vẫn đợi đủ 3s và trả 200** → `shutdown_complete` sau đó, process thoát sạch |
| Log | mỗi dòng đúng 1 JSON record phẳng: `time, level, event, ..., message` |

`dotnet test app.Tests/NodeRegistry.Tests.csproj` — **12/12 pass** (3 config/nodes
+ 4 http, tương ứng 7 test Rust cũ). `dotnet format --verify-no-changes` sạch cho
cả 2 project.

## Chưa làm

- `docker compose up` thật với MySQL container (curl `/items` POST/GET qua DB
  thật, không chỉ DB chết) — logic SQL giống hệt bản cũ nên rủi ro thấp, nhưng
  chưa có bằng chứng chạy thật với DB sống.
- Cập nhật `evidence/M9.md` chính thức bằng số Trivy ở trên khi tới D14 (bảng
  so sánh Rust vs .NET).

## Đã xong (cập nhật 2026-09-18, sau khi có quyền `sudo docker`)

- ~~`docker build` thật~~ — xong, xem bảng Trivy + kiểm chứng container ở trên.
- ~~Cập nhật GitHub ruleset `protect-main`~~ — xong: required status check đổi
  từ `rust (fmt, clippy, test)` sang `dotnet (format, build, test)`, thêm
  `terraform plan (infra/app)` (D9). PR #6, #7 đã merge vào `main`.

## File đã đổi

`app/*.cs`, `app/NodeRegistry.csproj`, `app/Dockerfile`, `app/.env.example`,
`app/.dockerignore` · `app.Tests/` (mới) · `docker-compose.yml` (bỏ `RUST_LOG`)
· `Makefile` (`run/test/lint/fmt/check` → `dotnet`) · `.github/workflows/ci.yml`
(job `rust` → `dotnet`) · `.gitignore` (`target/` → `bin/`, `obj/`) ·
`.github/pull_request_template.md` (checklist).

`evidence/d04/`, `evidence/d05/`, `notes/d4.md`, `notes/d5.md`, `notes/d6.md`
**giữ nguyên** — đó là bằng chứng lịch sử của bản Rust tại thời điểm làm, không
sửa lại cho khớp hiện tại (sẽ sai lệch với ngày ghi).

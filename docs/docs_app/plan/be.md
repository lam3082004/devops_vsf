# Kế hoạch backend — `app/be`

Hợp đồng: [api-spec.md](../api-spec.md) · [database-schema.md](../database-schema.md) · [prd.md](../prd.md) mục 2.
Quy ước thư mục: `app/be/CLAUDE.md`. Chỉ mục: [README.md](README.md).

## Khuôn mẫu phải theo (tái sử dụng, không viết lại)

| Việc | Mẫu có sẵn |
|---|---|
| Controller → Service → Repository, DI qua constructor | `Controllers/ItemsController.cs` |
| Lỗi nghiệp vụ trả bằng `Result<T>`, không throw | `Services/NodeService.cs:20-29` |
| Validator là hàm thuần Try-pattern, test không cần DB | `Validation/NodeRequestValidator.cs` |
| Tham số query nhận `string?` rồi tự parse (không để model binding tự xử) | `Controllers/LoadController.cs` + `LoadService` |
| SQL thuần ADO.NET, `AddWithValue`, raw string `"""` | `Repositories/NodeRepository.cs` |
| Map reader → record: `IsDBNull` + `DateTime.SpecifyKind(…, Utc)` | `Repositories/NodeRepository.cs:76-85` |
| Log một dòng JSON, field đầu là `("event", …)` | `Infrastructure/IAppLogger.cs` |
| Schema idempotent lúc khởi động | `Repositories/DatabaseRepository.cs:13-29` |
| Tên test tiếng Việt không dấu PascalCase | `Boom_Tra500_VaKhongLamChetApp` |

Ranh giới giữ nguyên: `Result` cho lỗi **dự kiến** (validate, không tìm thấy, xung đột) → 4xx ·
exception cho lỗi **hạ tầng** → `DatabaseExceptionFilter` biến thành `503 database_unavailable`.

---

## BE-1 — Nền kỹ thuật · `feat/be-foundation`

Chưa đụng domain. Gỡ hết những chỗ khuôn mẫu hiện tại không phủ, để BE-2 không phải vừa đổi domain vừa sửa nền.

### 1. Hết trùng lặp `Program.cs` ↔ `HttpTests.cs`

Bốn khối đang bị copy nguyên xi. Thêm service mà quên một nơi thì test đỏ theo kiểu khó đoán:

| Khối | `Program.cs` | `HttpTests.cs` |
|---|---|---|
| `ConfigureJson` | 53-59 | 82-86 |
| Đăng ký DI | 61-81 | 43-60 |
| `AddJsonOptions` + `ConfigureHttpJsonOptions` | 76, 81 | 59, 60 |
| Middleware + `MapFallback` | 109-113 | 63-66 |

Tách `app/be/Infrastructure/ApiSetup.cs` với `AddOpsBoard(...)`, `ConfigureJson(...)`, `ConfigureApiBehavior(...)`;
hai host cùng gọi. **V5 sẽ thêm host test thứ ba** nên đây là lúc rẻ nhất để làm.

Bỏ sót `ConfigureHttpJsonOptions` thì 404 của `MapFallback` sẽ khác 404 của controller — lỗi im lặng.

### 2. `Result<T>` phân biệt được 400 / 404 / 409

Hiện `Error` chỉ là string nên controller luôn map thành 400. Thêm vào `Common/Result.cs`:
```csharp
public enum ErrorKind { Validation, NotFound, Conflict }

public ErrorKind Kind { get; }                                    // chỉ có nghĩa khi !IsSuccess
public static Result<T> Fail(string e)     => new(false, default, e, ErrorKind.Validation);  // 400, như cũ
public static Result<T> NotFound(string e) => new(false, default, e, ErrorKind.NotFound);
public static Result<T> Conflict(string e) => new(false, default, e, ErrorKind.Conflict);
```
`Fail(string)` giữ nguyên nghĩa "400" → `LoadService` **không phải sửa một dòng nào**.
Không cần `Result` non-generic: rà `api-spec.md`, mọi thao tác đều trả về một giá trị.

Gom map sang HTTP vào `Controllers/ApiControllerBase.cs` để controller không tự `switch`:
```csharp
protected IActionResult Failure<T>(Result<T> r) => r.Kind switch
{
    ErrorKind.NotFound => NotFound(new ErrorResponse("not_found")),          // không kèm reason
    ErrorKind.Conflict => Conflict(new ErrorResponse("invalid_transition", Reason: r.Error)),
    _                  => BadRequest(new ErrorResponse("bad_request", Reason: r.Error)),
};
```

### 3. Enum ra JSON đúng chuỗi snake_case

`ConfigureJson` chưa có converter → `status`/`severity`/`category` sẽ serialize ra **số**, sai hợp đồng.
Thêm `new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower, allowIntegerValues: false)`
(`allowIntegerValues: false` để client gửi `{"status": 2}` bị từ chối thay vì đoán mò).

**Query string là đường binding khác.** `?status=in_progress` đi qua MVC model binding
(`Enum.Parse(ignoreCase: true)`), **không** qua System.Text.Json, nên `in_progress` sẽ không khớp `InProgress`;
bind lỗi thì `[ApiController]` tự trả **ProblemDetails**, phá hợp đồng `ErrorResponse`. Vì vậy `GET /items`
nhận tham số lọc dưới dạng `string?` rồi parse trong validator thuần — đúng khuôn `/load?seconds=` đang dùng.

Một nguồn sự thật cho tên dây, dùng cho cả parse query, ghi cột `ENUM`, và ghi `from_value`/`to_value`:
```csharp
public static class EnumNames<TEnum> where TEnum : struct, Enum
{
    public static string ToWire(TEnum v) => JsonNamingPolicy.SnakeCaseLower.ConvertName(v.ToString());
    public static bool TryParse(string? raw, out TEnum value);   // "in_progress" → InProgress
}
```

> `JsonConsoleLogger.ToJsonValue` không biết enum nên sẽ log ra tên C# (`InProgress`).
> Khi log ticket phải truyền `EnumNames<TicketStatus>.ToWire(status)`, đừng truyền enum thẳng.

### 4. Lỗi model binding phải ra `ErrorResponse`

Đi kèm bắt buộc với mục 3: không có nó thì JSON hỏng, enum lạ, sai kiểu đều trả ProblemDetails,
lệch `api-spec.md` ("Lỗi luôn theo dạng `ErrorResponse`"). Đăng ký trong `ApiSetup.AddOpsBoard`, và
**phải đứng SAU `AddControllers(...)`**: `AddControllers` tự đăng ký một `IConfigureOptions<ApiBehaviorOptions>`
đặt factory về ProblemDetails, mà các configure chạy theo thứ tự đăng ký nên khai trước sẽ bị ghi đè
(ai-failure-log #13).
```csharp
o.InvalidModelStateResponseFactory = ctx =>
{
    var field = ctx.ModelState.Keys.FirstOrDefault()?.TrimStart('$', '.') ?? "body";
    return new BadRequestObjectResult(new ErrorResponse("bad_request", Reason: $"'{field}' khong hop le"));
};
```
Chỉ lấy **tên field**, không đẩy message gốc của System.Text.Json ra ngoài — message đó chứa tên kiểu C#.

### 5. Null: đảo mặc định thay vì rải attribute

`api-spec.md` yêu cầu `ErrorResponse` bỏ field null, còn DTO dữ liệu luôn trả đủ field.
`ErrorResponse` là kiểu **duy nhất** cần bỏ null (`HealthResponse`/`VersionResponse`/`LoadResponse` không có
field nullable). Nên **đảo mặc định**: đặt `DefaultIgnoreCondition = Never` toàn cục, chỉ `ErrorResponse`
mang attribute. Hai attribute trong một file, thay vì sáu attribute rải trên bốn file — và DTO thêm về sau
mặc định *đúng* mà không ai phải nhớ:
```csharp
public sealed record ErrorResponse(
    string Error,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Reason = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Detail = null);
```
Record positional **phải** dùng `[property: …]`; gắn thẳng lên tham số thì attribute không vào property.
Hành vi quan sát được giữ nguyên 100%.

> **Phải sửa `api-spec.md` mục "Quy ước chung" trong cùng PR** — chỗ đó đang gợi ý cách cài đặt ngược lại
> (`[JsonIgnore(Condition = Never)]` trên từng DTO). Hợp đồng quan sát được không đổi, chỉ đổi cách làm.

### 6. Cắt ngang: trace và người dùng

- Middleware gắn header `X-Trace-Id`. Ba nguồn theo thứ tự: `Activity.Current?.TraceId` → trace-id trong header
  `traceparent` của frontend → sinh ngẫu nhiên. **`Activity.Current` thường là `null`** vì app gọi
  `Logging.ClearProviders()` nên không có listener (ai-failure-log #12) — D20 bật OpenTelemetry thì nhánh 1 mới có giá trị.
- `RequestLoggingMiddleware` thêm field `trace_id` (cạnh `request_id` đang có).
- Action filter đọc header `X-User-Name`, validate 1–50 ký tự, thiếu → `400 bad_request`. Chỉ áp cho POST/PATCH.
  Đặt tên đã chuẩn hoá vào `HttpContext.Items` để service lấy làm `reporter`/`actor`.

**Test BE-1:** `X-Trace-Id` có mặt · thiếu `X-User-Name` → 400 · enum ra `"in_progress"` không phải số ·
`EnumNames.TryParse` từ chối `"IN_PROGRESS"` và `"2"` · `ErrorResponse` vẫn bỏ field null · body hỏng → `ErrorResponse`.

---

## BE-2 — Domain Ticket thay Node · `feat/be-ticket-domain`

PR lớn nhất. `/items` đổi hợp đồng **trong cùng một PR** để không có bước trung gian gãy.

| Thêm | Xoá |
|---|---|
| `Models/Ticket.cs` + enum `TicketStatus`/`Severity`/`Category`/`ActivityAction` | `Models/Node.cs`, `RegisterNodeRequest.cs` |
| `Contracts/TicketResponse.cs` + hàm map entity → DTO | — |
| `Validation/TicketRequestValidator.cs` | `Validation/NodeRequestValidator.cs` |
| `Repositories/TicketRepository.cs` + interface | `NodeRepository.cs`, `INodeRepository.cs` |
| `Services/TicketService.cs` + interface | `NodeService.cs`, `INodeService.cs` |
| `TicketValidatorTests.cs` | `NodesTests.cs` |

**Sửa nợ kỹ thuật:** `/items` hiện trả thẳng entity `Node`, trái quy ước `Contracts/` trong `app/be/CLAUDE.md`.
Domain Ticket phải đi qua DTO.

### Schema — 3 bảng, thứ tự quan trọng
`EnsureSchemaAsync` hiện chạy **một** statement; MySqlConnector không cho multi-statement → **một
`ExecuteNonQueryAsync` cho mỗi `CREATE TABLE`**, tuần tự trên cùng connection:
```
tickets  →  comments  →  activities
```
`tickets` phải trước vì hai bảng kia có khoá ngoại trỏ vào nó (MySQL từ chối FK tới bảng chưa tồn tại, errno 1824).
Không bọc transaction: DDL trong MySQL tự implicit-commit, bọc chỉ tạo ảo giác nguyên tử.
DDL **copy nguyên văn** từ `database-schema.md` kể cả `KEY ix_*` và `ON DELETE CASCADE`
(cascade này còn là công cụ dọn dữ liệu ở BE-5). Bảng `nodes` cũ để nguyên, không `DROP`.

Đổi luôn log ở `Program.cs:88` (`"bang nodes san sang"`) và dòng "Hợp đồng không được phá" trong `app/be/CLAUDE.md`.

### `GET /items`
Lọc `status`, `severity`, `category`, `assignee`, `unassigned=true`, `q`, `limit` (mặc định 20, tối đa 100),
`offset`. Sắp `updated_at DESC`. Trả `{items, total, limit, offset}` — `total` là tổng **sau khi lọc**
(`COUNT(*)` riêng, cùng điều kiện).

Hai chỗ dễ sai:
- `unassigned=true` cùng lúc `assignee=` → `400`.
- `q`: escape `%`, `_`, `\` trước khi ghép vào `LIKE '%…%'`, tối đa 100 ký tự. Không escape thì người dùng gõ `%`
  sẽ tự tạo wildcard.

### `POST /items`
Chỉ `title` bắt buộc; `severity` mặc định `medium`, `category` mặc định `other`, `status` = `open`,
`reporter` = `X-User-Name`. Insert ticket + activity `created` trong **một transaction**.

---

## BE-3 — Chi tiết, cập nhật, chuyển trạng thái · `feat/be-ticket-transitions`

### `GET /items/{id}`
Trả `{ticket, activities}` (activity tăng dần). Không có → `404 not_found`.
Bình luận **không** nằm trong response này — frontend gọi riêng.

### `PATCH /items/{id}`
Sửa `title`, `description`, `severity`, `category`, `assignee`. **Không** sửa `status` ở đây.

Phân biệt **vắng mặt** (không đổi) với **gửi `null`** (xoá giá trị) bằng `JsonElement` **KHÔNG nullable**
(không phải `JsonElement?`): vắng mặt → `default(JsonElement)` → `ValueKind == Undefined`; gửi `null` →
`ValueKind == Null`; có giá trị → `ValueKind` thật. Dùng `string?` thường thì hai trường hợp này không phân
biệt được. **`JsonElement?` (`Nullable<JsonElement>`) cũng KHÔNG dùng được** — `NullableConverter` chặn token
JSON `null` và trả C# `null` trước khi converter của `JsonElement` chạy, nên vắng mặt và null tường minh đều
cho `HasValue == false` (xem `ai-failure-log.md` #15, phát hiện bằng probe .NET thật, không phải suy đoán).

### `PATCH /items/{id}/status`
State machine theo `prd.md` mục 2, viết thành **hàm thuần** để test không cần DB:

| Từ | Sang được |
|---|---|
| `open` | `in_progress` |
| `in_progress` | `open`, `resolved` |
| `resolved` | `in_progress` (mở lại), `closed` |
| `closed` | (không) |

Sai → `409 invalid_transition`, `reason` dạng `"open -> resolved khong hop le"` (dùng `EnumNames.ToWire`).
Cùng trạng thái hiện tại cũng `409`.

Hiệu ứng phụ: sang `resolved` ghi `resolved_at`; mở lại xoá `resolved_at`; sang `in_progress` mà trống
`assignee` thì gán actor.

### Transaction — mẫu chuẩn cho toàn repo
Repo **chưa có tiền lệ nào**. Nguyên tắc: **một method repository = một transaction**, service không bao giờ
thấy `MySqlConnection`. Service quyết nghiệp vụ (transition hợp lệ chưa, sinh activity nào, `resolved_at`
set hay xoá) rồi đưa **trạng thái đích đã tính xong** cho repository ghi nguyên khối:
```csharp
Task<Ticket?> UpdateAsync(long id, TicketUpdate update, IReadOnlyList<ActivityWrite> activities,
                          TicketStatus? expectedStatus, CancellationToken ct);
```
Bốn chi tiết dễ sai:
- **`cmd.Transaction = tx` cho mọi command** trong khối, kể cả câu SELECT đọc lại — MySqlConnector ném
  `InvalidOperationException` nếu command có `Transaction = null` khi connection đang mở transaction.
- `WHERE id=@id AND (@expected IS NULL OR status=@expected)` chống TOCTOU giữa lúc service đọc và lúc ghi.
  `affected == 0` sau khi đã `GetAsync` thành công nghĩa là có người đổi trước → `409`.
- **Đọc lại ticket trong transaction** để lấy `updated_at` mới (`ON UPDATE CURRENT_TIMESTAMP`).
- Enum ghi xuống cột `ENUM(...)` là **string**: `AddWithValue("@status", EnumNames<TicketStatus>.ToWire(...))`.

Ghi activity cho **mọi** trường đổi (7 `action`). Với `title_changed`/`description_changed` thì
`from_value`/`to_value` để `null` — cột chỉ `VARCHAR(200)` mà description tới 5000 ký tự.

---

## BE-4 — Bình luận và thống kê · `feat/be-comments-stats`

- `GET /items/{id}/comments` tăng dần theo thời gian · `POST` body 1–2000 ký tự, `author` = `X-User-Name`.
  Không sửa, không xoá (PRD US-06). Ticket không tồn tại → `404`.
- `GET /stats`: `total`, `by_status`, `by_severity`, `open_critical`, `avg_resolution_minutes`
  = `AVG(TIMESTAMPDIFF(MINUTE, created_at, resolved_at))` trên ticket có `resolved_at`, **`null`** khi chưa có
  ticket `resolved` (field vẫn phải xuất hiện — xem BE-1 mục 5).

> **Bẫy:** đừng dùng `Dictionary<TicketStatus,int>` cho `by_status`. Enum làm *key* không đi qua
> `JsonStringEnumConverter` theo cùng quy tắc như value, và dictionary sẽ **thiếu key khi count = 0** trong khi
> spec đòi đủ 4 key. Dùng record tường minh — `PropertyNamingPolicy` tự cho ra `in_progress`:
> ```csharp
> public sealed record StatsByStatus(int Open, int InProgress, int Resolved, int Closed);
> ```

---

## BE-5 — Test tích hợp MySQL thật trong CI · `feat/be-integration-tests`

Bộ test hiện tại **không chạm DB** (`HttpTests.cs:22-25`: `MySqlDataSource` lazy nên tạo được mà không kết nối),
nên mọi lỗi SQL chỉ lộ khi chạy thật. Người dùng đã chốt thêm MySQL thật vào CI.

**Không thêm NuGet package nào.** `MySqlConnector` đã sang `be.Tests` qua `ProjectReference`. xUnit 2.9.2 chưa có
`Assert.Skip`, nhưng đặt `Skip` trong constructor của một `FactAttribute` con thì test báo *skipped* ngay ở
giai đoạn discovery:
```csharp
public sealed class RequiresMySqlFactAttribute : FactAttribute
{
    public RequiresMySqlFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TEST_DB_HOST")))
            Skip = "khong co MySQL: dat TEST_DB_HOST de chay";
    }
}
```
Dùng tiền tố **`TEST_DB_*`** chứ không dùng thẳng `DB_HOST`: ai lỡ `set -a; . app/be/.env.local` trong shell
sẽ không vô tình cho test xoá sạch DB dev của mình.

**Chống skip im lặng.** Rủi ro lớn nhất của cơ chế skip: gõ sai tên biến trong YAML → toàn bộ test DB skip →
CI vẫn xanh. Một test thuần chặn việc đó (GitHub Actions luôn đặt `CI=true`):
```csharp
[Fact] public void TrongCI_PhaiCoBienMoiTruongMySql()
{
    if (Environment.GetEnvironmentVariable("CI") != "true") return;
    Assert.False(string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TEST_DB_HOST")));
}
```

**Cô lập dữ liệu:** một schema dùng chung, dọn bằng `DELETE FROM tickets` — FK `ON DELETE CASCADE` dọn luôn
`comments` và `activities`. Không tạo database per-test (chậm, cần quyền cao), không transaction-rollback
(không dùng được vì app tự mở connection riêng). `[Collection("mysql")]` trên các class chạm DB là **bắt buộc** —
xUnit chạy song song theo collection, hai class cùng `DELETE FROM tickets` song song sẽ phá nhau.
Test thuần nằm ngoài collection nên vẫn chạy song song.

| File | Loại | Kiểm gì |
|---|---|---|
| `TicketValidatorTests.cs` | thuần | ràng buộc độ dài, escape `q`, `unassigned` + `assignee` → lỗi |
| `StatusTransitionTests.cs` | thuần | đủ 16 ô bảng PRD (`[Theory]`), `closed` là ngõ cụt, same-state → 409 |
| `JsonContractTests.cs` | thuần | `"status":"in_progress"`, `"assignee":null` **có mặt**, `ErrorResponse` **không** có `reason` khi null |
| `HttpTests.cs` (có sẵn) | thuần | giữ nguyên |
| `TicketsApiTests.cs` | **DB** | POST → 201 + activity `created`, GET 404, PATCH vắng-mặt-vs-null, status 409, `/stats` |
| `TicketRepositoryTests.cs` | **DB** | `UpdateAsync` với `expectedStatus` lệch → `null` **và activities không tăng** |

Bài đáng tiền nhất là `StatusLech_Rollback_KhongThemActivity` — thứ duy nhất chứng minh `cmd.Transaction = tx`
không bị quên, mà mock không bao giờ bắt được.

### CI — `.github/workflows/ci.yml`, job `dotnet` (hiện dòng 42-59)
```yaml
    services:
      mysql:
        image: mysql:8.4
        env:
          MYSQL_ROOT_PASSWORD: testpass      # DB dùng một lần trong runner, không phải secret
          MYSQL_DATABASE: opsboard_test
        ports: ["3306:3306"]
        # Thiếu health check thì step test chạy trước lúc MySQL nhận kết nối → đỏ ngẫu nhiên.
        options: >-
          --health-cmd="mysqladmin ping -h 127.0.0.1 -u root -ptestpass"
          --health-interval=5s --health-timeout=3s --health-retries=20
```
Bước `dotnet test` nhận `TEST_DB_HOST=127.0.0.1`, `TEST_DB_PORT=3306`, `TEST_DB_USER=root`,
`TEST_DB_PASSWORD=testpass`, `TEST_DB_NAME=opsboard_test` qua `env:`.

`testpass` entropy thấp nên không kích rule gitleaks; tiền lệ là `devpass` trong `docker-compose.yml` đã qua được.
Đừng đặt giá trị trông như secret thật ở đây.

Thêm target local tận dụng container `d4-mysql` (cổng 3307):
```makefile
## Test đầy đủ kèm MySQL thật (make test vẫn skip phần DB)
test-db: db-up
	TEST_DB_HOST=127.0.0.1 TEST_DB_PORT=3307 TEST_DB_USER=root \
	TEST_DB_PASSWORD=devpass TEST_DB_NAME=opsboard \
	dotnet test app/be.Tests/OpsBoard.Tests.csproj
```
Ghi vào `local-dev.md`: `make test` **bỏ qua** phần SQL, đừng tưởng nó đã phủ.

---

## BE-6 — Dữ liệu mẫu · `chore/seed-data`

`app/be/seed.sql`: 15–20 ticket rải đủ 4 trạng thái, vài bình luận, đủ để demo và đo `/stats`.
Nạp bằng tay (`local-dev.md`). **Không làm endpoint seed** — một route tạo dữ liệu hàng loạt không xác thực
là rủi ro nếu lỡ để mở trên Azure.

---

## Thứ tự bắt buộc

BE-1 mục 3 (`ApiSetup` + `EnumNames`) phải xong **trước** mục 5 và BE-3, vì `EnumNames.ToWire` chính là thứ
repository dùng để ghi cột `ENUM` và ghi `from_value`/`to_value`.

## Kiểm chứng

```
export DOTNET_ROOT=$HOME/.dotnet PATH="$HOME/.dotnet:$PATH"
make check          # dotnet format + test + fe lint/build
make test-db        # từ BE-5: test kèm MySQL thật
```
Chạy thật:
```
docker rm -f d4-mysql && make db-up     # DB đã đổi tên nodereg → opsboard
make run
curl localhost:8080/health
curl -H 'X-User-Name: Lam' -H 'Content-Type: application/json' \
     -d '{"title":"MySQL het ket noi","severity":"critical","category":"database"}' \
     localhost:8080/items
curl -X PATCH -H 'X-User-Name: Lam' -H 'Content-Type: application/json' \
     -d '{"status":"in_progress"}' localhost:8080/items/1/status
curl 'localhost:8080/items?status=in_progress&limit=5'
curl localhost:8080/stats
```
Image (đã kiểm 2026-09-21: build xanh, 184MB, `/version` trả SHA thật):
```
sg docker -c "docker build -f app/be/Dockerfile app/be \
  --build-arg GIT_SHA=$(git rev-parse --short HEAD) -t opsboard-be:test"
```

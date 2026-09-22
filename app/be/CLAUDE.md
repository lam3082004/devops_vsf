# app/be — backend .NET (OpsBoard)

Quy ước riêng cho thư mục này. File `CLAUDE.md` ở gốc repo và `~/.claude/CLAUDE.md` vẫn áp dụng;
khi xung đột, file gần code nhất thắng. Yêu cầu sản phẩm: `docs/docs_app/`.

## Stack
.NET 10 · ASP.NET Core MVC · MySqlConnector · image `aspnet:10.0-noble-chiseled` (non-root, không shell).
Frontend Next.js ở `app/fe/` (có `app/fe/CLAUDE.md`) — **không** đặt code frontend vào đây. Xem thêm `../CLAUDE.md`.

## Kiến trúc trong app
`Controller → Service → Repository`, DI qua constructor. Controller chỉ map HTTP ↔ Service; nghiệp vụ ở Service;
SQL chỉ ở Repository. Bỏ lớp Service khi không có nghiệp vụ (xem `BoomController`).

- `Models/` entity + enum; `Contracts/` DTO trả ra ngoài — không trả entity trực tiếp.
- Lỗi nghiệp vụ trả bằng `Result<T>` (`Common/Result.cs`), không ném exception cho luồng thường.
- Trạng thái, mức độ, phân loại là **enum**, không so sánh chuỗi. Chuyển trạng thái sai → lỗi rõ ràng.
- JSON snake_case. **DTO dữ liệu giữ field null** (frontend gõ kiểu được), chỉ `ErrorResponse` bỏ field null —
  mặc định toàn cục là `Never`, `ErrorResponse` tự mang attribute ngược lại (`Infrastructure/ApiSetup.cs`).
  Mọi lỗi dùng `ErrorResponse` (`error`, `reason`, `detail`); map mã HTTP qua `Controllers/ApiControllerBase.Failure`.
- Log chỉ qua `IAppLogger` (1 dòng JSON/record, có `event`). Không `Console.WriteLine`, không log giá trị secret.
- Config chỉ đọc từ biến môi trường ở `Infrastructure/Config.cs`. Thiếu biến hoặc còn `@Microsoft.KeyVault(` → thoát lỗi rõ.
- Schema tạo idempotent (`CREATE TABLE IF NOT EXISTS`) lúc khởi động; SQL luôn tham số hoá.

## Hợp đồng không được phá
`/health` · `/version` · `/load` · `/boom` · `/items` (bảng ticket) — đề bài `topic.md` mục 2 dựa vào chúng.
Đổi tên hay đổi response của 5 route này cần cập nhật `docs/docs_app/api-spec.md` và test cùng PR.
`/health` **không** phụ thuộc dịch vụ ngoài (kể cả Jev); chỉ ping DB.

## Việc không tự làm
- Không thêm NuGet package mới nếu chưa được duyệt; nêu lý do và giá trị trong PR.
- Không đưa secret/connection string vào code, `appsettings`, log. Không đọc `.env.local` (chứa mật khẩu dev).
- Không bật Swagger ngoài Development.
- Không gọi dịch vụ ngoài (Jev...) trong đường xử lý request chính khi chưa có timeout + fallback.

## Kiểm chứng (chạy trước khi nói "xong")
```
make test     # dotnet test app/be.Tests/OpsBoard.Tests.csproj
make lint     # dotnet format --verify-no-changes
docker build -f app/be/Dockerfile app/be --build-arg GIT_SHA=$(git rev-parse --short HEAD)
```
Chạy local: `make db-up` rồi `make run`. Test thêm tính năng đi kèm test (service + http).

## Quy trình
Nhánh `feat/` · `fix/` · `chore/` → PR → squash merge, không push `main`. Mỗi PR có mục `## AI usage`.
Mỗi lần AI sinh sai phát hiện được → thêm 1 dòng vào `ai-failure-log.md`.
Không `terraform apply` / `az ... create` khi chưa được người dùng xác nhận trong phiên.

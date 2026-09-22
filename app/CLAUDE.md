# app/ — OpsBoard

Hai phần độc lập, mỗi phần có `CLAUDE.md` riêng (đọc file gần code nhất):

| Thư mục | Công nghệ | Vai trò |
|---|---|---|
| `be/` | .NET 10, ASP.NET Core MVC, MySqlConnector | API ticket + endpoint hạ tầng (`/health`, `/version`, `/load`, `/boom`) |
| `be.Tests/` | xUnit | Test của `be/` (tách khỏi `be/` để `dotnet` không biên dịch lẫn vào app) |
| `fe/` | Next.js (App Router), TypeScript, Tailwind | Giao diện; route handler phía server gọi `be/` (BFF) |

- Hợp đồng giữa hai phần: `docs/docs_app/api-spec.md`. Đổi API → sửa spec + test + frontend cùng PR.
- Yêu cầu sản phẩm và wire-frame: `docs/docs_app/`.
- Frontend không chứa secret; địa chỉ backend qua `API_BASE_URL` (server-side).
- Lệnh: `make test`/`make lint` (be) · `make fe-lint`/`make fe-build` (fe). Chi tiết trong từng `CLAUDE.md`.

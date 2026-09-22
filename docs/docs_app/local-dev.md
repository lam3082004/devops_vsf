# Local dev — OpsBoard

Chạy backend và frontend cùng lúc trên máy dev, không qua Docker Compose (compose hiện chỉ dựng `db` + `be`,
xem cuối file). Liên quan: [api-spec](api-spec.md) · [architecture](architecture.md).

## Chạy backend (`app/be`)
```
make db-up      # dựng/khởi động container MySQL local (mysql:8.4), chờ tới khi healthy
make run        # dotnet run --project app/be/OpsBoard.csproj
```
`make run` cần `app/be/.env.local` (copy từ mẫu, không commit — đã ở `.gitignore`):
```
cp app/be/.env.example app/be/.env.local
```
Mặc định trong mẫu đã khớp với `make db-up` (`DB_HOST=127.0.0.1`, `DB_PORT=3307`, `DB_USER=root`).

> **Một lần duy nhất sau khi đổi tên (2026-09-21):** database local đổi từ `nodereg` sang `opsboard`.
> Container `d4-mysql` tạo trước đó vẫn giữ tên cũ vì `make db-up` chỉ `docker start` lại container có sẵn.
> Xoá và dựng lại (mất dữ liệu dev, không sao):
> ```
> docker rm -f d4-mysql && make db-up
> ```
> Đồng thời sửa `DB_NAME=opsboard` trong `app/be/.env.local` nếu file đó tạo từ trước.
> *(Đã chạy sẵn trên máy này 2026-09-21 — database `opsboard` đang tồn tại.)*

## Chạy frontend (`app/fe`)
```
make fe-install   # npm --prefix app/fe ci — chỉ cần chạy 1 lần (hoặc sau khi đổi package.json)
make fe-dev        # npm --prefix app/fe run dev
```
Cần `app/fe/.env.local` (copy từ `app/fe/.env.example`), tối thiểu:
```
API_BASE_URL=http://localhost:8080
```
`API_BASE_URL` chỉ route handler phía server (BFF) của Next.js dùng — không lộ ra trình duyệt.

## Cổng
| App | Cổng | Kiểm tra nhanh |
|---|---|---|
| `be` | 8080 | `curl localhost:8080/health` → `{"status":"ok","db":"ok"}` |
| `fe` | 3000 | mở `http://localhost:3000` |

## Cổng gác trước khi mở PR
```
make check   # be: dotnet format --verify-no-changes + dotnet test · fe: npm run lint + npm run build
```
`make check` phải sạch trước khi đẩy PR — đây cũng là những gì `.github/workflows/ci.yml` chạy cho code.

**`make test` (và do đó `make check`) BỎ QUA phần test chạm MySQL thật** — các test đó dùng
`[RequiresMySqlFact]`/`[RequiresMySqlTheory]` (`app/be.Tests/RequiresMySqlFactAttribute.cs`), tự skip khi
thiếu biến `TEST_DB_HOST`. `make test` xanh **không** chứng minh phần tích hợp SQL (state machine, escape
`q`, rollback transaction...) đã được kiểm — xem `app/be.Tests/TicketsApiTests.cs` và
`TicketRepositoryTests.cs`. Muốn chạy đủ, dùng:
```
make test-db   # chạy sau make db-up, trỏ vào container d4-mysql:3307 (be.md BE-5)
```
`.github/workflows/ci.yml` chạy tương đương `test-db` bằng một service container MySQL riêng trong CI
(cổng 3306, DB `opsboard_test`) — không dùng `d4-mysql`.

## Lưu ý `dotnet` trên máy này
`/usr/bin/dotnet` là bản hỏng (thiếu `host/fxr`); SDK thật nằm ở `~/.dotnet`. **`~/.bashrc` đã trỏ sẵn**
(`DOTNET_ROOT` + `PATH`) nên terminal bình thường chạy được ngay. Chỉ shell **không tương tác** (script, CI cục bộ,
tiến trình do công cụ khác sinh ra) mới phải tự đặt:
```
export DOTNET_ROOT=$HOME/.dotnet
export PATH="$HOME/.dotnet:$PATH"
```

## Dữ liệu mẫu (dev / demo)
`app/be/seed.sql` chứa 18 ticket rải đủ 4 trạng thái (`open`/`in_progress`/`resolved`/`closed`) và đủ 4 mức
độ (`low`/`medium`/`high`/`critical`), kèm `activities`/`comments` mẫu. Script idempotent: xoá dữ liệu
ticket cũ rồi nạp lại (`DELETE FROM tickets` — nhờ `ON DELETE CASCADE`, một câu này dọn sạch cả `comments`
và `activities`), nên nạp lại nhiều lần vẫn ra đúng cùng 18 ticket đó. Nạp **bằng tay** khi cần:
```
docker exec -i d4-mysql mysql -uroot -pdevpass opsboard < app/be/seed.sql
```
(`d4-mysql` là tên container do `make db-up` tạo — xem `DB_CONTAINER` trong `Makefile`.)
Cố tình **không làm endpoint seed** — một route tạo dữ liệu hàng loạt không xác thực là rủi ro nếu lỡ để
mở trên Azure thật (không có auth thật, chỉ IP whitelist).

## `docker-compose.yml` hiện có gì
Chỉ hai service: `db` (MySQL 8.4, cổng host `3307`) và `app` (backend `be`, cổng host `8080`). **Chưa có
service cho `fe`** — chạy frontend bằng `make fe-dev` như trên, không qua compose. Thêm service `fe` vào
compose là việc chưa làm (theo dõi ở `docs/plans/active/azure-app-service-internship.md`).

## Công cụ cần có trên máy

| Công cụ | Cài thế nào | Vì sao |
|---|---|---|
| .NET 10 SDK | có sẵn ở `~/.dotnet` | `export DOTNET_ROOT=$HOME/.dotnet PATH="$HOME/.dotnet:$PATH"` — bản `/usr/bin/dotnet` hỏng |
| Node 24 | nvm | `make fe-*` |
| Docker | nhóm `docker` | `make db-up`. Terminal chưa nạp nhóm thì `newgrp docker` (hoặc `sg docker -c "<lệnh>"`) |
| Docker Compose | plugin ở `~/.docker/cli-plugins` | tuỳ chọn; `make db-up` không cần |
| **gitleaks + pre-commit hook** | **`bash scripts/install-hooks.sh`** | chặn secret **trước khi** vào lịch sử git |

> `.git/hooks/` **không theo repo**, nên clone mới là mất hook — đã xảy ra một lần trên máy này (phát hiện
> 2026-09-21). CI vẫn quét, nhưng lúc đó secret đã nằm trong commit rồi. Chạy `scripts/install-hooks.sh`
> ngay sau khi clone.

Kiểm thử hook: tạo file chứa một khoá AWS giả, `git add`, rồi `git commit` — phải bị chặn.

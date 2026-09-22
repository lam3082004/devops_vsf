# Kế hoạch viết app OpsBoard

Kế hoạch **code ứng dụng**. Yêu cầu sản phẩm nằm ở `docs/docs_app/` (đó là authority — file này chỉ nói làm
theo thứ tự nào). Kế hoạch **hạ tầng** 25 ngày ở `docs/plans/active/azure-app-service-internship.md`.

| File | Nội dung |
|---|---|
| [be.md](be.md) | Backend .NET (`app/be`) — 6 PR từ nền kỹ thuật tới test tích hợp |
| [fe.md](fe.md) | Frontend Next.js (`app/fe`) — 5 PR từ nền tới màn hình thống kê |

## Điểm xuất phát (2026-09-21)

Backend đã có `/health`, `/version`, `/load`, `/boom`, log JSON, Dockerfile, 12 test — nhưng domain vẫn là
`Node` (bảng `nodes`: `name`/`address`/`role`). Frontend mới là khung Next.js trống. Việc phải làm: thay domain
bằng `Ticket`/`Comment`/`Activity` và dựng 6 màn hình.

**Bốn endpoint hạ tầng không được đổi hợp đồng** — `topic.md` mục 2 và bằng chứng M2/M10/M11 dựa vào chúng.

> **Cập nhật 2026-09-22: TOÀN BỘ PLAN XONG (BE-1→BE-6, FE-1→FE-5).** 4 trang chạy thật với backend + MySQL;
> hành trình tạo→kanban→chi tiết→bình luận→đổi trạng thái→thống kê thông suốt; tắt backend thì cả 4 trang
> hiện banner lỗi có nút "Thử lại", không trắng trang. Còn lại: chia commit/PR.
>
> **Plan backend (BE-1→BE-6).** 139 test, trong đó **12 test chạm MySQL thật**
> (`make check` skip chúng, `make test-db` chạy chúng). CI đã có `services: mysql:8.4`.
> `app/be/seed.sql` cho 18 ticket đủ 4 trạng thái, `/stats` ra `avg_resolution_minutes = 185`.
> Còn lại: **FE-2→FE-5** (kanban, danh sách, chi tiết, thống kê) và việc chia commit/PR.

## Quyết định đã chốt

| Quyết định | Ngày | Ghi chú |
|---|---|---|
| Tên kỹ thuật `OpsBoard` (đổi từ `NodeRegistry`) | 2026-09-21 | `var.db_name` trên Azure vẫn `appdb` |
| Hai service `fe` + `be` trên cùng App Service Plan (Q10) | 2026-09-21 | CD, swap, whitelist, Trivy đều phải làm hai lần |
| Kanban kéo thả bằng `@dnd-kit` | 2026-09-21 | Dependency mới, đã được duyệt |
| Test backend có **MySQL thật trong CI** | 2026-09-21 | `services:` container trong job `dotnet` |
| R5 (chỉ chặn theo IP, không xác thực `fe`→`be`) chấp nhận | 2026-09-21 | Xem `brief.md` mục 8 |
| Q1 (App Insights) chưa quyết | — | **Không chặn**: `trace_id` lấy từ `traceparent`/`Activity.Current`, OpenTelemetry chỉ thêm exporter |

## Thứ tự PR

Làm backend trước để API ổn định rồi mới dựng giao diện. Nhánh sống tối đa 2 ngày, squash merge, không push `main`.

```
BE-1 nền kỹ thuật ──▶ BE-2 domain Ticket ──▶ BE-3 chuyển trạng thái ──▶ BE-4 comment + stats
                                    │                                        │
                                    └──────────▶ FE-1 nền ──▶ FE-2 kanban    ├──▶ BE-5 test tích hợp
                                                                 │           └──▶ BE-6 seed
                                                   FE-3 danh sách + tạo
                                                   FE-4 chi tiết
                                                   FE-5 thống kê
```

FE-1 bắt đầu được ngay sau BE-2 (đã có `GET`/`POST /items` thật để gọi). FE-4 cần BE-3 và BE-4 xong.

| PR | Nhánh | Trạng thái |
|---|---|---|
| BE-1 | `feat/be-foundation` | **xong** 2026-09-21 — 38 test pass (trước 12) |
| BE-2 | `feat/be-ticket-domain` | **xong** 2026-09-21 — 62 test pass; PO đã kiểm chạy thật trên MySQL |
| BE-3 | `feat/be-ticket-transitions` | **xong** 2026-09-21 — 106 test pass; PO kiểm state machine + TOCTOU trên MySQL thật; codex soi độc lập không thấy bug |
| BE-4 | `feat/be-comments-stats` | **xong** — 124 test; PO kiểm `/stats` + comments trên MySQL thật |
| BE-5 | `feat/be-integration-tests` | **xong** — CI có `services: mysql:8.4`; `make test-db` 0 skipped; PO kiểm bằng cách trỏ sai DB → đúng 12 test đỏ |
| BE-6 | `chore/seed-data` | **xong** 2026-09-22 — `app/be/seed.sql` 18 ticket / 7 bình luận / 31 activity |
| FE-1 | `feat/fe-foundation` | **xong** 2026-09-21 — types, api client, 4 BFF route, NameGate, layout, 4 trạng thái UI |
| FE-2 | `feat/fe-kanban` | **xong** 2026-09-22 — PO kiểm HTML render: số đếm cột khớp `/stats`, viền đỏ đúng định nghĩa `open_critical`, BFF 200/409/400/404 đúng |
| FE-3 | `feat/fe-list-create` | **xong** 2026-09-22 — PO kiểm: lọc/phân trang khớp `/stats`, URL rác không sập, tạo ticket 201/400 đúng |
| FE-4 | `feat/fe-detail` | **xong** 2026-09-22 — PO kiểm: PATCH chỉ đổi trường đã gửi, `assignee:null` xoá đúng, `status` → 400, lịch sử hiện "đã tạo ticket" |
| FE-5 | `feat/fe-stats` | **xong** 2026-09-22 — PO kiểm cả DB rỗng ("chưa có dữ liệu", không NaN) lẫn có seed (185 phút → "3 giờ 5 phút", 8/8 số khớp API) |

## Luật áp dụng cho mọi PR

- Cổng gác: `make check` phải sạch (be: `dotnet format` + `dotnet test` · fe: `npm run lint` + `next build`).
- Mỗi PR có mục `## AI usage` ghi rõ phần nào AI viết.
- Đổi hợp đồng API → sửa `api-spec.md` + test + frontend **trong cùng PR** (`app/CLAUDE.md`).
- Mỗi lần AI sinh sai → một dòng trong `ai-failure-log.md`.
- Không thêm dependency mới ngoài `@dnd-kit` đã duyệt.
- `~/.bashrc` đã trỏ sẵn `DOTNET_ROOT`/`PATH` tới `~/.dotnet` (bản `/usr/bin/dotnet` hỏng); chỉ shell không tương tác mới phải tự export.

## Việc dọn phát hiện lúc kiểm chứng

Không phải việc mới, nhưng nên làm sớm:

1. ~~Pre-commit hook gitleaks đã biến mất~~ — **đã sửa 2026-09-21**: cài `gitleaks` 8.30.1 vào `~/.local/bin`,
   dựng lại `.git/hooks/pre-commit`, thêm `scripts/install-hooks.sh` để clone mới cài lại được.
   Đã kiểm: secret giả → chặn (exit 1), cây sạch → cho qua (exit 0).
2. ~~`docker compose` không dùng được~~ — **đã sửa 2026-09-21**: cài compose plugin v5.5.1 vào
   `~/.docker/cli-plugins` (không cần sudo). `docker compose config` chạy được.
3. **`next/font/google`** trong `app/fe/src/app/layout.tsx` tải font Geist lúc build → build Docker/CI cần mạng
   tới Google Fonts. Cân nhắc font hệ thống nếu build offline. **Chưa xử lý.**
4. **Git chưa có identity trên máy này** (`user.name`/`user.email` đều trống) → `git commit` local sẽ hỏng.
   Mọi commit trong lịch sử đều là squash merge từ GitHub nên trước giờ chưa cần. Đặt trước khi commit lần đầu.

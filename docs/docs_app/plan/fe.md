# Kế hoạch frontend — `app/fe`

Hợp đồng: [wire-frame.md](../wire-frame.md) (6 màn hình) · [prd.md](../prd.md) (US-01…US-08) ·
[api-spec.md](../api-spec.md) (API). Quy ước thư mục: `app/fe/CLAUDE.md`. Chỉ mục: [README.md](README.md).

## Điểm xuất phát
Khung `create-next-app` trống: Next.js 16.3.5 · React 19.2.8 · TypeScript strict · Tailwind v4 · App Router ·
alias `@/*` → `src/*` · `output: "standalone"` (để đóng Docker ở D16). Chỉ có `src/app/{layout,page}.tsx`.

## Luật kiến trúc
**Trình duyệt không bao giờ gọi `be` trực tiếp.** Mọi lời gọi đi qua server component hoặc route handler đọc
`process.env.API_BASE_URL` (architecture.md). Lý do: `API_BASE_URL` trỏ tới địa chỉ nội bộ của backend và không
được lộ ra client; đây cũng là chặng `fe → be` tạo nên distributed tracing thật.

> `app/fe/AGENTS.md` do Next.js sinh cảnh báo bản này có breaking change so với kiến thức cũ. Khi vướng API lạ,
> đọc `node_modules/next/dist/docs/` trước khi đoán.

---

## FE-1 — Nền · `feat/fe-foundation`

### Kiểu dữ liệu — `src/lib/types.ts`
Khớp đúng `api-spec.md`. Union thay vì enum để khớp dây JSON:
```ts
export type TicketStatus = "open" | "in_progress" | "resolved" | "closed";
export type Severity = "low" | "medium" | "high" | "critical";
export type Category = "infra" | "app" | "database" | "network" | "security" | "other";

export interface Ticket {
  id: number; title: string; description: string | null;
  severity: Severity; category: Category; status: TicketStatus;
  reporter: string; assignee: string | null;
  created_at: string; updated_at: string; resolved_at: string | null;
}
export interface TicketList { items: Ticket[]; total: number; limit: number; offset: number; }
```
Backend **luôn trả đủ field kể cả null** (BE-1) nên dùng `| null`, **không** dùng `?`. Nếu gõ `?` thì
TypeScript sẽ không bắt được chỗ quên xử lý null.

### Client — `src/lib/api.ts` (chỉ chạy phía server)
`getTickets`, `getTicket`, `createTicket`, `patchTicket`, `patchStatus`, `getComments`, `addComment`, `getStats`.
- Chuyển tiếp `X-User-Name` (thao tác ghi) và `traceparent` (mọi lời gọi, để trace nối được `fe → be`).
- Đọc `ErrorResponse` và ném lỗi **có kiểu**, giữ `error` + `reason` + HTTP status. `409 invalid_transition`
  phải giữ được `reason` để kanban hiện đúng lý do.
- `cache: "no-store"` cho mọi lời gọi đọc — dữ liệu ticket đổi liên tục, cache của Next sẽ cho ra bảng cũ.

### Route handlers — `src/app/api/**`
BFF cho các thao tác ghi mà client component gọi (kéo thả, bình luận, tạo ticket). Nhận `X-User-Name` từ client,
gọi `api.ts`, trả nguyên `ErrorResponse` về cho client xử lý.

### `NameGate` — US-01
Nhập tên → `localStorage`, chưa có tên thì mọi thao tác ghi bị chặn và hiện hộp nhập (wire-frame S1).
Tên 1–50 ký tự. Một context React nhỏ cho các component khác đọc tên; header `👤 <tên>` mở lại hộp để đổi.

### Layout
Thanh điều hướng `Board · Danh sách · Thống kê` + nút `+ Ticket` (wire-frame mục "Điều hướng chung").
Sửa `lang="en"` → `lang="vi"` trong `src/app/layout.tsx` (scaffold để mặc định).

### Bốn trạng thái giao diện phải có ngay từ đầu
`wire-frame.md` mục cuối và PRD US-08: **đang tải** (skeleton) · **rỗng** ("Chưa có ticket") ·
**lỗi backend** (banner + nút thử lại, không trắng trang) · **403** ("IP của bạn chưa được phép").
Làm thành component dùng chung ở FE-1, các màn hình sau chỉ việc dùng lại.

---

## FE-2 — Kanban (S2) · `feat/fe-kanban`

**Thêm dependency** `@dnd-kit/core@6.3.1` + `@dnd-kit/sortable@10.0.0` — người dùng đã duyệt 2026-09-21.
Đã kiểm tương thích: peer `react >=16.8.0`, repo đang React 19.2.8. Ghi lý do vào `## AI usage` của PR.
Component kéo thả phải `"use client"`.

### Lấy dữ liệu
Không có endpoint nhóm theo trạng thái. Gọi `GET /items` **4 lần song song**, mỗi lần
`?status=<open|in_progress|resolved|closed>&limit=20`. Số đếm mỗi cột lấy từ **`total`** của chính response đó,
**không phải `items.length`** (`items` chỉ có tối đa 20 dòng). Cột `Closed` vì vậy chỉ hiện 20 thẻ mới nhất;
nút "xem tất cả" điều hướng sang S3 với `status=closed`.

### Kéo thả
Thả sang cột khác → `PATCH /items/{id}/status`. Cập nhật lạc quan (thẻ nhảy cột ngay), nhưng
**`409` → trả thẻ về chỗ cũ + toast hiện `reason`** từ backend (PRD US-03). Đây là chỗ dễ làm ẩu nhất:
nếu nuốt lỗi thì giao diện nói một đằng, database một nẻo.

Dropdown/thao tác chỉ nên mời những chuyển hợp lệ, nhưng **vẫn phải xử lý 409** — backend là trọng tài cuối cùng,
và hai người dùng có thể kéo cùng một thẻ.

### Thẻ
Hiện tiêu đề, severity, assignee, tuổi ticket (từ `created_at`). Ticket `critical` **đang mở** nổi bật hơn
(viền đỏ) theo wire-frame.

---

## FE-3 — Danh sách + tạo ticket (S3, S4) · `feat/fe-list-create`

**Danh sách:** lọc `status`/`severity`/`category`/`assignee`/`unassigned`, tìm `q`, phân trang (mặc định 20,
tối đa 100). Giữ bộ lọc trên URL query string để chia sẻ được link và quay lại không mất trạng thái.
`unassigned=true` và `assignee=` không được gửi cùng lúc (backend trả 400).

**Tạo ticket (hộp thoại S4):** chỉ `title` bắt buộc. Lỗi validate hiện **dưới từng ô**, và
**không mất dữ liệu đã nhập** (PRD US-02) — đừng reset form khi lỗi. Ràng buộc độ dài lấy từ `prd.md`:
title ≤200, description ≤5000, assignee ≤50. Validate ở client để phản hồi nhanh, nhưng backend vẫn là trọng tài.

---

## FE-4 — Chi tiết ticket (S5) · `feat/fe-detail`
Cần BE-3 và BE-4 xong.

**Hai lời gọi riêng, không gộp:** `GET /items/{id}` (ticket + lịch sử) và `GET /items/{id}/comments`.

- Sửa tiêu đề, mô tả, severity, category, assignee → `PATCH /items/{id}`. Để bỏ phân công thì gửi
  `assignee: null`; **không gửi field** nghĩa là không đổi (api-spec.md). Đây là chỗ dễ sai: gửi cả object
  mỗi lần sẽ ghi đè trường người khác vừa sửa.
- Đổi trạng thái → `PATCH /items/{id}/status`. Dropdown **chỉ hiện chuyển hợp lệ** từ trạng thái hiện tại
  (bảng trong `prd.md` mục 2).
- Bình luận: thêm được, **không sửa không xoá** (US-06). Hiện theo thời gian kèm tên và giờ.
- Lịch sử: đọc `activities`. Với `title_changed`/`description_changed` thì `from_value`/`to_value` là `null` —
  hiện "đã đổi tiêu đề" chứ đừng hiện "null → null".

---

## FE-5 — Thống kê (S6) · `feat/fe-stats`
`GET /stats` → 3 ô số (tổng · critical đang mở · thời gian xử lý trung bình) + 2 thanh phân bố
(theo trạng thái, theo mức độ). `avg_resolution_minutes` có thể là `null` khi chưa ticket nào `resolved` —
hiện "chưa có dữ liệu", không hiện `0` (sai nghĩa).

---

## Kiểm chứng

```
make fe-install                 # một lần
make fe-lint && make fe-build   # hoặc make check (chạy cả be)
```
Chạy cùng backend thật (`local-dev.md`):
```
docker rm -f d4-mysql && make db-up
make run        # backend :8080
make fe-dev     # frontend :3000  (cần app/fe/.env.local có API_BASE_URL=http://localhost:8080)
```
Cuối mỗi PR frontend, mở `http://localhost:3000` và đi hết đường: nhập tên → tạo ticket → kéo thả đổi trạng thái
→ thử kéo sai luật (phải thấy thẻ quay về + lý do) → bình luận → xem thống kê. Tắt backend một lát để kiểm
trạng thái lỗi (US-08) không trắng trang.

`next build` chạy `tsc` nên lỗi kiểu sẽ làm PR đỏ — đó là cổng gác kiểu dữ liệu, đừng dùng `any` để lách.

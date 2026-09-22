# Wire-frame — OpsBoard

Khung thô, chưa phải thiết kế thị giác. Next.js (App Router, `app/fe`). Viewport mục tiêu ≥ 1280 px.

## Điều hướng chung
```
┌────────────────────────────────────────────────────────────────────────┐
│ OpsBoard   [Board] [Danh sách] [Thống kê]            [+ Ticket]  👤 Lâm │
└────────────────────────────────────────────────────────────────────────┘
```
`👤` mở lại hộp nhập tên. Banner đỏ phía trên khi backend không phản hồi.

## S1 — Nhập tên (lần đầu / đổi tên)
```
┌───────────────────────────┐
│ Bạn là ai?                │
│ [ Tên (1–50 ký tự)      ] │
│                 [ Vào ]   │
└───────────────────────────┘
```
Lưu localStorage. Chưa có tên thì mọi trang khác chuyển về S1.

## S2 — Bảng kanban (trang chủ)
```
 Lọc: [severity ▾] [assignee ▾] [category ▾]  🔍 [tìm tiêu đề…]
┌─ Open (4) ────────┬─ In progress (2) ─┬─ Resolved (1) ────┬─ Closed (9) ──────┐
│┌─────────────────┐│┌─────────────────┐│┌─────────────────┐│┌─────────────────┐│
││🔴 CRITICAL      │││🟠 HIGH          │││🟢 LOW           │││🟡 MEDIUM        ││
││MySQL hết kết nối│││API /items chậm  │││Sai màu dashboard│││Log đầy đĩa      ││
││database · 2h    │││app · 5h  @Lâm   │││app · 1d  @Nam   │││infra · 3d @Nam  ││
│└─────────────────┘│└─────────────────┘│└─────────────────┘│└─────────────────┘│
│  … kéo thả thẻ    │                   │                   │                   │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┘
```
- Kéo thẻ sang cột = đổi trạng thái. Không hợp lệ → thẻ về chỗ cũ + toast lý do.
- Bấm thẻ mở S5. Thẻ `critical` đang mở viền đỏ.
- Cột `Closed` chỉ hiện 20 thẻ mới nhất, có liên kết "xem tất cả" sang S3.
- Dữ liệu 4 cột: gọi `GET /items?status=<X>&limit=20` 4 lần song song, số đếm mỗi cột lấy từ `total` của
  response đó (xem "Cách frontend dựng kanban" ở `api-spec.md`).

## S3 — Danh sách
```
 Lọc: [status ▾] [severity ▾] [category ▾] [assignee ▾]  🔍 [tìm…]
┌────┬──────────────────────┬──────────┬──────────┬──────────┬──────────┬───────┐
│ #  │ Tiêu đề              │ Severity │ Status   │ Assignee │ Category │ Tạo   │
├────┼──────────────────────┼──────────┼──────────┼──────────┼──────────┼───────┤
│ 41 │ MySQL hết kết nối    │ critical │ open     │ —        │ database │ 2h    │
│ 40 │ API /items chậm      │ high     │ progress │ Lâm      │ app      │ 5h    │
└────┴──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────┘
                                              [‹ Trước]  Trang 1/3  [Sau ›]
```

## S4 — Tạo ticket (hộp thoại)
```
┌─ Tạo ticket ──────────────────────────────┐
│ Tiêu đề*      [                          ]│
│ Mô tả         [                          ]│
│               [                          ]│
│ Mức độ        (•) medium ( ) low ( ) high ( ) critical │
│ Phân loại     [ other ▾ ]                 │
│ Người xử lý   [ (trống) ▾ ]                │
│                      [ Huỷ ]  [ Tạo ]      │
└───────────────────────────────────────────┘
```
Lỗi validate hiện dưới từng ô; giữ nguyên dữ liệu đã nhập.

## S5 — Chi tiết ticket
```
┌────────────────────────────────────────────────────────┬───────────────────┐
│ #41  MySQL hết kết nối                        [Sửa]    │ Trạng thái        │
│ Mô tả: …                                               │ [in_progress ▾]   │
│                                                        │ Mức độ  [critical]│
│ ── Bình luận ──────────────────────────────────────    │ Phân loại [db]    │
│ Lâm · 14:02  Đang xem connection pool                  │ Người xử lý [Lâm] │
│ Nam · 14:10  Đã tăng max_connections                   │ Người báo   Nam   │
│ [ Viết bình luận…                          ] [Gửi]     │ Tạo   21/09 13:50 │
│                                                        │ ── Lịch sử ──     │
│                                                        │ 14:00 open→in_prog│
│                                                        │ 13:50 tạo (Nam)   │
└────────────────────────────────────────────────────────┴───────────────────┘
```
Danh sách trạng thái chỉ hiện các chuyển hợp lệ từ trạng thái hiện tại (PRD mục 2).

## S6 — Thống kê
```
┌─ Tổng ─┐ ┌─ Critical đang mở ─┐ ┌─ TB xử lý ──┐
│   57   │ │        3           │ │  4 giờ 12 p │
└────────┘ └────────────────────┘ └─────────────┘
 Theo trạng thái  ▇▇▇▇ open ▇▇ progress ▇ resolved ▇▇▇▇▇▇ closed
 Theo mức độ      ▇ critical ▇▇ high ▇▇▇▇ medium ▇▇▇ low
```

## Trạng thái giao diện phải có
Đang tải (skeleton) · rỗng ("Chưa có ticket") · lỗi backend (banner + nút thử lại) · 403 (thông báo "IP của bạn chưa được phép").

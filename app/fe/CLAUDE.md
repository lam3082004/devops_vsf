@AGENTS.md

# app/fe — frontend Next.js (OpsBoard)

Đọc thêm `../CLAUDE.md` và `docs/docs_app/` (PRD, wire-frame, api-spec). Khối bên trên do Next.js sinh: giữ nguyên.

- TypeScript strict; kiểu response khớp `docs/docs_app/api-spec.md` (`Ticket`, `Comment`, `Activity`, enum `status|severity|category`). Không dùng `any`.
- Trình duyệt **không** gọi backend trực tiếp: đi qua route handler/server component trong `src/app`, đọc `process.env.API_BASE_URL`.
- Người dùng chỉ nhập tên (lưu localStorage), gửi qua header `X-User-Name` khi ghi; giữ `traceparent` khi gọi backend.
- Không secret, không dữ liệu công ty trong code hay `.env.example`. `.env.local` không commit.
- Không thêm npm package mới nếu chưa được duyệt; nêu lý do trong PR. `output: "standalone"` để đóng Docker.
- Kiểm chứng: `npm run lint` · `npm run build` (từ `app/fe`) hoặc `make fe-lint` / `make fe-build`.
- Mỗi PR có mục `## AI usage`.

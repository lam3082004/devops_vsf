# docs/docs_app — tài liệu ứng dụng OpsBoard

Đọc theo thứ tự: **brief → prd → wire-frame → api-spec → database-schema → architecture**. `local-dev.md`
đọc riêng khi cần chạy máy local. Bắt tay vào code thì xem [plan/README.md](plan/README.md).

| File | Nội dung |
|---|---|
| [brief.md](brief.md) | Vấn đề, giải pháp, người dùng, mục tiêu, phạm vi, ràng buộc, rủi ro và câu hỏi mở |
| [prd.md](prd.md) | Từ vựng, quy tắc nghiệp vụ (trạng thái, ràng buộc dữ liệu), user story và tiêu chí chấp nhận |
| [wire-frame.md](wire-frame.md) | Khung màn hình (kanban, danh sách, tạo, chi tiết, thống kê) — chưa phải thiết kế thị giác |
| [api-spec.md](api-spec.md) | Hợp đồng API backend (`app/be`): endpoint, request/response, mã lỗi, quy ước |
| [database-schema.md](database-schema.md) | Schema MySQL: sơ đồ ER, DDL, quyết định thiết kế |
| [architecture.md](../../architecture.md) (đã chuyển ra gốc repo, D24) | Thành phần hệ thống, luồng traffic/xác thực/triển khai, observability, quyết định |
| [local-dev.md](local-dev.md) | Chạy backend + frontend trên máy dev, dữ liệu mẫu, cổng gác trước PR |
| [plan/](plan/README.md) | **Kế hoạch code app** — thứ tự PR cho backend ([be.md](plan/be.md)) và frontend ([fe.md](plan/fe.md)) |

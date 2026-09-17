# D1 — Azure 101 · RBAC · chi phí (2026-09-15)

Nhật ký đầy đủ: `notes/d1.md`

## Kết quả kiểm chứng (Azure CLI, 2026-09-15)

| Mục | Giá trị |
|---|---|
| Subscription | `Azure subscription 1` · `9880aa34-1fb4-4402-b692-232a90f1a7bb` |
| Tenant | VINACADEMY LLC (`vinuni.edu.vn`) · `58f82789-6695-4f4a-abdb-357668d55cff` = ID của Tenant Root Group |
| Role của mình | **Owner** × 2 ở scope subscription, `condition = null` (không bị ABAC giới hạn) |
| Chính sách tenant | `allowedToCreateApps = false` → **không tạo được app registration** ⇒ D7 phải dùng user-assigned MI + federated credential |
| Providers | 8 provider cần dùng đã Registered · **thiếu**: `Microsoft.Storage` (cần cho D7), `Microsoft.AlertsManagement` (D22) |
| Defender for Cloud | mọi plan trả phí = `Free`; coverage 0/0 plans |
| Budget | `budget-intern` — 50 USD/tháng, alert 50/80/100% actual + 100% forecasted, không action group |
| Region đã chọn | **Southeast Asia** — MySQL B1ms và App Service P0V3 đều khả dụng |

## Giá tham chiếu (Retail Prices API, Southeast Asia, Linux, USD/giờ)

B1 0.018 · S1 0.095 · **P0v3 0.0915** · P0v4 0.0949 · P1v3 0.183
MySQL B1ms 0.026 (+ storage 0.138/GB-tháng) · ACR Basic 0.1666/ngày · Log Analytics 2.99/GB · Key Vault 0.03/10K ops

## Ảnh
Ảnh chụp của ngày này **đã mất** (bộ nhớ đệm ảnh của phiên chat bị xoá). Toàn bộ nội dung đọc được từ ảnh đã chuyển thành chữ trong `notes/d1.md`. Từ D2 trở đi ảnh được lưu ngay vào repo.

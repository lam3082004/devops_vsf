# Brief — OpsBoard: quản lý ticket lỗi và đầu việc cho team vận hành

**Trạng thái:** bản nháp 2026-09-21 · **Người phụ trách:** Bùi Tùng Lâm

## Tên
`OpsBoard` là tên sản phẩm **và** tên kỹ thuật — đổi xong 2026-09-21: `app/be/OpsBoard.csproj`,
`app/be.Tests/OpsBoard.Tests.csproj`, namespace `OpsBoard.*`, assembly `OpsBoard.dll`, `DB_NAME=opsboard`
(local). Tên `NodeRegistry` chỉ còn trong `notes/`, `evidence/` và `ai-failure-log.md` — đó là nhật ký lịch
sử, giữ nguyên.

Một chỗ **cố ý không đổi**: `var.db_name` trong `infra/app/variables.tf` vẫn là `appdb` (tên chung, không
phải tên cũ). Đổi nó sẽ tạo lại database trên Azure, không đáng.

## 1. Vấn đề
Lỗi hệ thống được báo lẻ tẻ qua chat hoặc nói miệng. Không có chỗ nào cho biết lỗi nào đang mở, mức độ nào,
ai đang xử lý, xử lý xong chưa và mất bao lâu.

## 2. Giải pháp
Ứng dụng web nội bộ: mỗi lỗi là một **ticket**; team theo dõi ticket trên **bảng kanban** (cột = trạng thái)
hoặc **danh sách** có lọc. Có phân công, bình luận, lịch sử thay đổi và thống kê.

## 3. Người dùng
Thành viên team vận hành, truy cập từ mạng công ty (cùng IP, nằm trong whitelist của App Service).
Không đăng nhập mật khẩu: người dùng nhập tên, tên đó ghi vào ticket/bình luận/lịch sử.
Chấp nhận rủi ro tên nhập giả — đây là công cụ nội bộ, danh tính dựa vào mạng tin cậy.

## 4. Mục tiêu
| # | Mục tiêu | Đo bằng |
|---|---|---|
| G1 | Tạo, phân công, đổi trạng thái ticket trong ≤ 3 thao tác | Kiểm thử thủ công theo PRD |
| G2 | Thấy ngay ticket nào `critical` đang mở | Bảng kanban + trang thống kê |
| G3 | Đủ nghiệp vụ để chứng minh hạ tầng: MySQL, Key Vault, health, zero-downtime, autoscale, alert, log, trace | `evidence/M1…M11` |
| G4 | Sẵn sàng nối Jev để tự phân loại ticket | Có điểm cắm `TriageProvider`, chưa gọi Jev thật |

## 5. Phạm vi
**Trong phạm vi:** CRUD ticket · kanban · danh sách lọc/tìm · phân công · bình luận · lịch sử · thống kê ·
giao diện Next.js · backend .NET · triển khai Azure App Service bằng Terraform + CI/CD.

**Ngoài phạm vi (lần này):** đăng nhập/phân quyền thật · email/thông báo · upload file · tự tạo ticket từ alert ·
gọi Jev thật · nhiều tổ chức · ứng dụng di động.

## 6. Ràng buộc
- Chỉ IP whitelist truy cập được (M6); runner CI/CD cần xử lý riêng.
- Môi trường Azure `make down` mỗi chiều — không phải dịch vụ chạy 24/7. Không để gì chạy qua đêm.
- Autoscale tối đa 2 instance. Chi phí trong budget của subscription học.
- Secret ở Key Vault; không dữ liệu hay config từ môi trường công ty thật trong repo. Ticket demo là dữ liệu tự sinh.
- Mọi thay đổi qua PR (trunk-based). Không thêm dependency/dịch vụ ngoài khi chưa được duyệt.

## 7. Công nghệ
Backend .NET 10 (`app/be`) · Frontend Next.js 16 + Tailwind (`app/fe`, đã khởi tạo) · MySQL 8.4 Flexible · Docker · Azure App Service · ACR · Key Vault ·
Managed Identity · Terraform · GitHub Actions · Log Analytics (+ tracing, chờ Q1).

## 8. Rủi ro và câu hỏi mở
| # | Nội dung | Ảnh hưởng |
|---|---|---|
| ~~R1~~ | **Đã chốt (Q10, 2026-09-21): hai service.** Chấp nhận gấp đôi CI/CD, swap, whitelist để đổi lấy trace có chặng `fe → be` thật. | — |
| R2 | Q1: được bật App Insights làm backend trace không? | Distributed tracing |
| R3 | Giao diện làm trễ M1–M11 | Điểm chính nằm ở hạ tầng; chỉ làm UI sau D10 |
| R4 | Jev là dịch vụ ngoài: giá, điều khoản, dữ liệu gửi đi chưa rõ | Chỉ thiết kế điểm cắm, chưa làm |
| R5 (**chấp nhận, không xử lý**) | `be` hiện chỉ chặn bằng access restriction (IP whitelist) trỏ outbound IP của `fe` + IP quản trị — **chưa có cơ chế xác nhận request thực sự đến từ `fe`** (không token, không mTLS); ai/thứ gì gọi được từ cùng dải IP công ty vẫn qua được vì access restriction chỉ lọc theo IP nguồn. Cách khác (header bí mật giữa `fe`↔`be`, Easy Auth, VNet integration…) **không làm lần này** — người dùng chấp nhận rủi ro 2026-09-21: công cụ nội bộ, mạng công ty là biên tin cậy, M6 chỉ yêu cầu chặn theo IP. | Kiến trúc, M6 — đã chấp nhận |
| R6 | `/boom` hiện trả `500` trực tiếp trong code (`return StatusCode(500, ...)`), **không ném exception thật**, trong khi `topic.md` mục 2 viết "ném exception". Nếu Q1 cho bật App Insights, cần đổi `/boom` sang ném exception thật (`throw`) để Failures blade ghi nhận được — chưa sửa code, chờ quyết định Q1. | App Insights Failures (M11) |

## 9. Mốc
Xem `docs/plans/active/azure-app-service-internship.md`. Giao diện chỉ bắt đầu sau GATE D10.

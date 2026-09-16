# D5 — Docker local · Trivy · Cost Analysis

**Cần:** D4, và D2–D3 đã chạy ≥ 1 ngày trước (để có số chi phí) · **Chi phí:** 0 · **Nhật ký:** `notes/d5.md`, `notes/cost-week1.md` · **AI-OFF**

## Mục tiêu
Đóng gói app thành image nhỏ, không chạy root, có SHA; chạy app + MySQL bằng compose; đo CVE ban đầu; đọc chi phí thật của D2–D3.

## 1. Dockerfile — yêu cầu cần đạt (tự viết)

| Yêu cầu | Vì sao | Cách kiểm chứng |
|---|---|---|
| Multi-stage: stage build có compiler/công cụ, stage chạy chỉ có kết quả | Ít package → ít CVE, image nhỏ | Kích thước image (ghi vào note) |
| Base image chạy tối giản (distroless / slim / alpine — tuỳ ngôn ngữ), **ghim tag cụ thể** | Build tái lập được | Không dùng `latest` |
| Nhận build argument cho git SHA và nhúng vào app | `/version` | Chạy container → `/version` trả SHA |
| Chạy bằng **user không phải root** | Giảm thiệt hại khi bị khai thác | Kiểm tra user của tiến trình trong container |
| Khai báo cổng app | App Service biết cổng | |
| Lệnh chạy dạng exec (app là PID 1) | Nhận SIGTERM | `docker stop` kết thúc nhanh, có log shutdown |
| `.dockerignore` loại `.git`, `infra/`, `notes/`, file env | Không lọt file thừa/secret vào image | Liệt kê file trong image |
| Không có secret trong image | Image nằm trong registry lâu dài | Xem lịch sử layer |

## 2. Build và chạy
1. Build với SHA = commit hiện tại (hoặc chuỗi thử nếu chưa có git commit).
2. Chạy container với các biến DB trỏ tới MySQL local.
3. Kiểm tra: `/version` đúng SHA · user không phải root · `docker stop` → log `shutdown_complete` trong vài giây (không bị kill sau 10s).
4. Ghi kích thước image.

## 3. Compose app + MySQL
Yêu cầu:
- Service MySQL 8 có **healthcheck**, volume dữ liệu, mật khẩu lấy từ file `.env` **không commit** (thêm vào `.gitignore`, kèm `.env.example` không có giá trị thật).
- Service app **chờ MySQL healthy** mới khởi động, map cổng ra máy.

Kiểm tra: `docker compose up` → `/health` 200 → POST/GET `/items` → `down` rồi `up` lại → dữ liệu còn (volume) → xoá volume → bảng được tạo lại tự động.

## 4. Trivy scan
1. Cài Trivy theo trang chính thức (aquasecurity) — máy hiện **chưa có** `trivy` (kiểm tra 2026-09-15).
2. Scan image vừa build. Ghi bảng vào note:

   | Base image | Kích thước | CRITICAL | HIGH | MEDIUM | LOW | Unfixed |
   |---|---|---|---|---|---|---|
   | (lựa chọn 1) | | | | | | |

3. Nếu còn CVE: thử base image khác hoặc cập nhật thư viện → scan lại → ghi dòng thứ hai.
4. Đọc kết quả: CVE nằm ở **OS package** hay **thư viện của app**? Có bản vá chưa?

## 5. Cost Analysis (chi phí thật D2–D3)
1. `Cost Management` → **Cost analysis** → scope **Azure subscription 1**.
2. View **Daily costs** · khoảng thời gian từ 15/09 tới hôm nay.
3. **Group by: Resource** → chụp. **Group by: Meter** → chụp.
4. Ghi vào `notes/cost-week1.md`:

   | Ngày | Resource | Meter | USD | So với ước tính (giờ chạy × giá/giờ) |
   |---|---|---|---|---|

5. Nếu chưa thấy số: dữ liệu trễ 8–24h — ghi lại và xem lại hôm sau.

## 6. Chuẩn bị GATE (viết bằng lời mình vào `notes/d5.md`)
- **State** là gì, lưu gì, mất thì sao?
- **Lock** chống chuyện gì?
- **Dependency** ngầm và tường minh khác nhau ra sao?

Dùng sổ khái niệm (mục D7, D8) để đối chiếu **sau khi** đã tự viết.

## Bẫy
- Build trên máy ARM (Mac M-series) ra image ARM → App Service (amd64) không chạy. Máy Linux x86 thì không gặp.
- `.env` bị commit → gitleaks D6 sẽ bắt, nhưng tốt nhất đừng để xảy ra.
- Healthcheck MySQL báo healthy trước khi MySQL nhận kết nối từ ngoài → app vẫn cần retry kết nối.
- Trivy DB lần đầu tải lâu; kết quả thay đổi theo ngày.

## Tự kiểm tra
1. Vì sao image nhỏ ít CVE hơn?
2. CVE "unfixed" xử lý thế nào?
3. Meter là gì? Vì sao chi phí thật khác ước tính?

## Xong khi
- [ ] image chạy non-root, `/version` đúng SHA, tắt êm · [ ] compose chạy được · [ ] bảng Trivy · [ ] `notes/cost-week1.md` có số thật (hoặc ghi rõ đang chờ dữ liệu) · [ ] 3 câu GATE tự viết

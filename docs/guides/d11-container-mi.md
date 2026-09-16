# D11 — Container pull từ ACR bằng Managed Identity

**Cần:** D10, image từ D5 · **Chi phí:** có (môi trường đang bật) · **Bằng chứng:** `evidence/M1.md`

> ⚠️ **Làm liền với D12.** App thật fail-fast khi thiếu biến DB/Key Vault (D4). Thứ tự an toàn: D12 mục 1–2 (cấu hình DB + Key Vault reference) → rồi mới đổi image sang app thật ở bài này. Hoặc tạm giữ placeholder cho tới khi D12 xong.

## Mục tiêu (M1)
App Service chạy image của bạn từ ACR; ACR admin **tắt**; việc pull dùng **user-assigned managed identity**.

## 1. Terraform: cấu hình pull bằng identity
Trên **cả Web App và slot staging**:
- Bật "dùng managed identity để pull từ container registry".
- **Chỉ định client ID** của user-assigned identity (nếu bỏ trống, nền tảng dùng system-assigned — không tồn tại → pull lỗi).
- Registry URL trỏ tới login server của ACR.
- `WEBSITES_PORT` = cổng app.
- Giới hạn thời gian khởi động container hợp lý (mặc định đủ cho app nhỏ).

PR → plan artifact: đọc xem chỉ những thuộc tính trên thay đổi → merge → `make up` (hoặc apply).

## 2. Đẩy image lần đầu (tay — CD sẽ tự động ở D16)
1. Tài khoản của bạn cần quyền **push** vào ACR (Owner thường đủ với chế độ quyền mặc định của ACR; nếu bị từ chối → thêm role AcrPush cho chính bạn qua Terraform bootstrap/app, ghi lại).
2. Đăng nhập registry **bằng danh tính Entra** (không dùng admin/password).
3. Build image với SHA = commit `main` hiện tại, tag `<acr>/vsf-app:<sha>` → push.
4. Portal: ACR → **Repositories** → thấy `vsf-app` với tag SHA.

## 3. Trỏ app sang image
- Đặt image của **slot staging** sang tag SHA (Portal → slot → **Deployment Center**, hoặc CLI) — bài này làm tay, D16 tự động.
- Mở **Log stream** của slot → quan sát: pull image → container start → log JSON `startup` của app.
- Swap staging → production. `/version` trên URL production trả **đúng SHA**.

## 4. Kiểm chứng M1 và chụp
| Bằng chứng | Ở đâu |
|---|---|
| ACR admin user **Disabled** | ACR → Settings → Access keys |
| App dùng managed identity để pull, đúng client ID | Web App → Deployment Center (hoặc Configuration) |
| Identity có role **AcrPull** trên ACR | ACR → Access control (IAM) → Role assignments |
| Log pull thành công | Log stream / container logs |
| `/version` = SHA | curl output kèm thời gian |
| Không có username/password registry trong app settings | Web App → Environment variables |

**Chứng minh ngược (khuyến khích):** tạm gỡ AcrPull (qua PR đổi biến) → restart slot staging với tag mới → pull **thất bại** trong log → trả quyền. Ghi thời gian.

## 5. `evidence/M1.md`
Mô tả luồng: App Service → token của user-assigned MI → ACR data plane → pull. Kèm các screenshot/log ở mục 4.

## Bẫy
- Pull lỗi *unauthorized* → quên client ID, gắn nhầm identity, hoặc AcrPull chưa lan truyền.
- Image build trên ARM → container thoát ngay với lỗi định dạng.
- Slot staging không có cấu hình pull → swap mang cấu hình sai sang production.
- Terraform apply sau đó kéo image về placeholder → thiếu `ignore_changes` (D9).
- App thoát do thiếu biến DB → xem D12 trước.

## Tự kiểm tra
1. Vì sao phải chỉ định client ID?
2. Token pull image lấy từ đâu, gửi tới đâu (control plane hay data plane)?
3. Nếu bật lại admin user thì M1 sai ở điểm nào dù app vẫn chạy?

## Xong khi
- [ ] production `/version` = SHA từ ACR · [ ] đủ 6 bằng chứng · [ ] `evidence/M1.md`

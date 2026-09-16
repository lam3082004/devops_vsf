# D21 — Log Analytics · KQL · Workbook

**Cần:** D16 (app thật đang chạy, có log JSON) · **Chi phí:** có — Log Analytics Analytics Logs **$2.99/GB** ingest ở Southeast Asia (Retail Prices API, 2026-09-15), app nhỏ thường vài cent · **Bằng chứng:** phần dashboard/log trong `evidence/M11.md`, `docs/logging.md`

## Mục tiêu (M11 — 3 dòng đầu)
- **App performance:** dashboard **không dùng App Insights**: response time · request rate · failure rate.
- **Infra:** App Service (CPU, memory, HTTP queue) + MySQL (CPU, connections, storage).
- **View log:** nghiên cứu giải pháp logging + dashboard xem log.

## 1. Terraform: workspace và diagnostic settings

| Resource | Cấu hình |
|---|---|
| Log Analytics workspace `log-vsf-<hậu tố>` | SKU PerGB2018 · **retention 30 ngày** · cùng region |
| Diagnostic setting cho **Web App** | category: `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, `AppServicePlatformLogs` (+ `AppServiceIPSecAuditLogs` nếu muốn thấy các request bị 403) · metrics: tất cả → workspace |
| Diagnostic setting cho **slot staging** | giống trên (slot là resource riêng) |
| Diagnostic setting cho **App Service Plan** | metrics → workspace |
| Diagnostic setting cho **MySQL** | metrics · log `MySqlSlowLogs` (tuỳ chọn) — audit log cần bật tham số server, tốn ingest → chỉ bật nếu cần |

Ghi Decision: category nào bật, category nào bỏ, vì sao (chi phí vs giá trị).

**Lưu ý vòng đời:** workspace bị destroy mỗi ngày → log cũ mất theo. Hai lựa chọn — ghi Decision:
- Chấp nhận mất log mỗi ngày (đơn giản, rẻ) — bằng chứng chụp trong ngày.
- Đưa workspace sang một stack sống lâu (như bootstrap) — log giữ qua các ngày, chi phí vẫn nhỏ.

## 2. Kiểm tra dữ liệu về
1. Apply → gọi vài request (`/items`, `/boom`, `/load?seconds=5`).
2. Chờ 5–15 phút (log có độ trễ).
3. Workspace → **Logs** → kiểm tra 3 bảng có bản ghi: `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, `AppServicePlatformLogs`.

## 3. Bộ truy vấn KQL (tự viết, lưu vào `docs/logging.md` kèm kết quả)

| # | Câu hỏi | Bảng | Gợi ý kỹ thuật |
|---|---|---|---|
| Q1 | Request rate theo 5 phút | HTTPLogs | đếm theo khoảng thời gian `bin` → vẽ biểu đồ thời gian |
| Q2 | Failure rate (% 5xx) theo 5 phút | HTTPLogs | đếm có điều kiện mã ≥ 500 chia tổng |
| Q3 | p50/p95 thời gian xử lý theo path | HTTPLogs | percentile trên cột thời gian xử lý, nhóm theo URI |
| Q4 | Parse log JSON của app | ConsoleLogs | cột chứa dòng log là chuỗi → `parse_json` → tách `level`, `path`, `status`, `duration_ms` |
| Q5 | Top lỗi `level=error` 1 giờ qua, kèm stack | ConsoleLogs | từ Q4, lọc level |
| Q6 | Container restart / pull image | PlatformLogs | lọc thông điệp khởi động/dừng container |
| Q7 | IP bị chặn 403 (nếu bật IPSecAuditLogs) | IPSecAuditLogs | nhóm theo IP nguồn |

Mỗi truy vấn: câu hỏi · truy vấn · screenshot kết quả · một câu kết luận.

## 4. Dashboard: Azure Workbook

Bố cục đề xuất (tham số thời gian ở đầu, áp cho mọi ô):

| Hàng | Ô | Nguồn |
|---|---|---|
| App performance | Response time (trung bình, p95) | metric Web App **Response Time** (hoặc Q3) |
| | Request rate | metric **Requests** |
| | Failure rate | metric **Http 5xx** / **Requests** (hoặc Q2) |
| Infra App Service | CPU %, Memory %, **Http Queue Length** | metric của **Plan** |
| Infra MySQL | CPU %, **Active connections**, **Storage %** | metric MySQL |
| Logs | Bảng lỗi mới nhất (Q5) · bảng request chậm nhất | KQL |

Quản lý bằng code (M8 "toàn bộ hạ tầng"): dựng Workbook trên Portal → **Advanced editor** → lấy JSON template → đưa vào Terraform (resource workbook với nội dung JSON, thay ID resource bằng biến). Kiểm chứng: destroy → apply → Workbook xuất hiện lại.

## 5. Nghiên cứu giải pháp logging → `docs/logging.md`

| Tiêu chí | Log Analytics + Workbook | Azure Managed Grafana (+ Azure Monitor/LA làm nguồn) | Tự dựng Loki + Grafana (container/VM) |
|---|---|---|---|
| Chi phí cố định | 0 (trả theo GB ingest) | có phí dịch vụ hằng giờ theo SKU | VM/container + storage chạy liên tục |
| Công vận hành | thấp | thấp–vừa | cao (nâng cấp, backup, bảo mật) |
| Ngôn ngữ truy vấn | KQL | KQL qua datasource + PromQL/LogQL nếu có nguồn khác | LogQL |
| Tích hợp Azure | sẵn (diagnostic settings) | tốt | phải tự đẩy log |
| Nhiều nguồn ngoài Azure | hạn chế | tốt | tốt |
| Terraform hoá | được | được | được, nhiều thứ hơn |
| Phù hợp dự án này | ✅ | quá mức cần | quá mức cần |

Thêm: bảng giá tra được (ghi ngày tra), ước tính GB/ngày thực tế đo từ workspace (**Usage and estimated costs**), kết luận.

## Bẫy
- Không có dữ liệu → quên diagnostic setting cho slot, hoặc chưa chờ đủ độ trễ.
- `AppServiceConsoleLogs` trống → app ghi log vào file thay vì stdout.
- Log JSON nhiều dòng → mỗi dòng một bản ghi, `parse_json` thất bại.
- Test tải sinh hàng nghìn dòng log → ingest tăng; giới hạn test ngắn.
- Metric "Response Time" và "Average Response Time" — dùng metric còn được hỗ trợ.
- Workbook tạo tay không vào Terraform → mất sau `make down`.

## Tự kiểm tra
1. Metric và log khác nhau thế nào, ô nào trong dashboard nên dùng cái nào?
2. Vì sao failure rate có thể lấy được mà không cần App Insights?
3. Hai nút vặn chi phí chính của Log Analytics?

## Xong khi
- [ ] workspace + diagnostic settings bằng Terraform · [ ] 7 truy vấn có kết quả · [ ] Workbook đủ 3 hàng + log, sống lại sau destroy/apply · [ ] `docs/logging.md` so sánh 3 giải pháp

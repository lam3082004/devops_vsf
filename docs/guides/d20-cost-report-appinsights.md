# D20 — Cost report · App Insights

**Cần:** D19, ≥ 2 ngày có dữ liệu Cost Analysis, câu trả lời **Q1** · **Deliverable:** `cost-report.md`, `evidence/M7.md`

## Mục tiêu (M7)
Báo cáo **1 trang**: tier đang dùng và tại sao · autoscale rule (max 2) · **3 biện pháp đã áp dụng** · **chi phí thật** từ Cost Analysis.

## 1. Lấy số thật
1. Cost Management → **Cost analysis** → scope subscription → khoảng thời gian từ 15/09 tới hôm nay.
2. View **Daily costs** → chụp (thấy rõ các ngày có/không bật môi trường).
3. **Group by: Service name** → chụp.
4. **Group by: Resource** → chụp.
5. Lọc theo tag `project = vsf` (nếu đã gắn tag từ D7) → chụp.
6. Ghi **ngày giờ lấy số** (dữ liệu trễ 8–24h).

## 2. Cấu trúc `cost-report.md` (1 trang)

```
# Cost report — <ngày>
## Tier và lý do
- App Service: P0V3 Linux — cần slot (M2) + autoscale (M7); B1 không có; P0V3 rẻ hơn/cấu hình tốt hơn S1 (bảng giá D19)
- MySQL: Burstable B1ms — tải thấp, tích credit CPU
- ACR Basic · Key Vault Standard · Log Analytics PerGB
## Autoscale
min 1 · max 2 · out CPU>70%/5m · in CPU<30%/10m · bằng chứng: evidence/M7.md
## 3 biện pháp đã áp dụng (có bằng chứng)
| Biện pháp | Bằng chứng | Tiết kiệm ước tính |
| 1. make up/make down theo ca — không chạy qua đêm | biểu đồ Daily costs có ngày bằng 0 / giờ chạy | (24h − giờ chạy) × giá/giờ |
| 2. … | | |
| 3. … | | |
## Chi phí thật
Tổng từ 15/09 → <ngày>: $…  (screenshot)
Theo dịch vụ: …
So sánh: nếu chạy 24/7 cùng cấu hình ≈ $…/tháng
## Chưa tối ưu / lần sau
```

Gợi ý biện pháp (chọn 3 cái **thật sự đã làm**):
- destroy/apply theo ca làm việc
- MySQL: backup retention 1 ngày, không geo backup, không HA, không auto-grow
- Log Analytics: chỉ category cần thiết + retention 30 ngày
- Không bật App Insights / Defender plans trả phí
- Autoscale max 2 thay vì chạy cố định 2 instance
- ACR Basic, không geo-replication

## 3. App Insights (theo Q1)

**Nếu được bật (chỉ cho exception `/boom`):**
- Workspace-based, gắn cùng Log Analytics workspace của D21 (tạo trước nếu cần).
- Connection string đưa vào app settings (không phải secret nhưng không commit giá trị cụ thể ngoài Terraform output).
- App gửi exception (SDK/OpenTelemetry của ngôn ngữ) — **thêm thư viện là dependency mới**: ghi Decision, kiểm tra Trivy.
- Sampling bật để giới hạn chi phí.
- Kiểm chứng: gọi `/boom` → App Insights → **Failures** → exception xuất hiện → chụp.
- Dashboard M11 **vẫn** dựng từ platform metrics (không dùng App Insights).

**Nếu không được bật:** ghi vào `known-issues.md`: "/boom được chứng minh qua AppServiceConsoleLogs + alert 5xx (D21–D22)".

## 4. `evidence/M7.md`
Screenshot autoscale (D19) · bảng right sizing · screenshot Cost Analysis · link `cost-report.md`.

## Bẫy
- Viết biện pháp "sẽ làm" → không tính.
- Số chi phí chụp quá sớm → thiếu 1 ngày gần nhất; ghi rõ thời điểm.
- Credit $200 được trừ → hoá đơn hiện 0 nhưng Cost Analysis vẫn có chi phí thực tế — báo cáo chi phí thực tế.
- App Insights thu mọi request → ingest tăng nhanh khi test tải.

## Tự kiểm tra
1. Biện pháp nào tiết kiệm nhiều nhất và vì sao?
2. Nếu phải chạy 24/7 cho người dùng thật, bạn đổi gì?

## Xong khi
- [ ] `cost-report.md` 1 trang, số thật, 3 biện pháp có bằng chứng · [ ] `evidence/M7.md` · [ ] App Insights xử lý theo Q1

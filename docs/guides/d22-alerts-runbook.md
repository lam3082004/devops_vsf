# D22 — 3 alert · trigger thật · runbook

**Cần:** D21, câu trả lời **Q3** (5xx count hay rate) và **Q5** (subscription sau 15/10) · **Bằng chứng:** `evidence/M11.md` · **Deliverable:** `runbook.md`

## Mục tiêu (M11 — dòng cảnh báo)
3 alert (**5xx rate · CPU cao · MySQL connections**) + action group gửi email + **trigger thật ít nhất 1 alert**.

> ⚠️ Kiểm tra trước: credit Free Trial hết hạn **15/10**. Nếu chưa chốt Q5, làm bài này trước ngày đó.

## 0. Provider
`Microsoft.AlertsManagement` đang **NotRegistered** (kiểm tra 2026-09-15) — register trước (qua bootstrap hoặc README prereq), nếu không trang Alerts/alert rule có thể lỗi.

## 1. Action group (Terraform)
- Tên `ag-vsf-oncall`, short name ≤ 12 ký tự.
- Receiver email: địa chỉ lấy từ **biến không commit** (file biến local / GitHub Variable) — không ghi email cá nhân vào repo.
- Portal → action group → **Test action group** → nhận email thử → chụp.

## 2. Ba alert rule (Terraform)

| Alert | Loại | Tín hiệu | Điều kiện đề xuất | Severity | Tần suất / cửa sổ |
|---|---|---|---|---|---|
| **5xx rate** | theo Q3: *count* → metric alert · *rate* → log alert (scheduled query) | count: metric **Http 5xx** của Web App · rate: KQL Q2 ở D21 (5xx / tổng) | count: tổng > 5 trong 5 phút · rate: > 5% **và** tổng request ≥ 20 | 1 (Error) | 5 phút / 5 phút |
| **CPU cao** | metric alert | **CPU Percentage** của **Plan** | trung bình > 80% trong 10 phút | 2 (Warning) | 1 phút / 10 phút |
| **MySQL connections** | metric alert | **Active connections** của MySQL | tối đa > ngưỡng bạn tự tính (xem dưới) trong 5 phút | 2 | 1 phút / 5 phút |

Ngưỡng MySQL connections: tra `max_connections` của B1ms (Portal → MySQL → Server parameters), lấy ~70–80%. Ghi cách tính vào Decision. Nếu muốn trigger thử được trong demo → ghi rõ ngưỡng demo khác ngưỡng thật.

Chung cho cả 3: gắn action group · bật **tự đóng khi hết điều kiện** (auto-mitigate) · mô tả alert có link tới `runbook.md`.

Lý do "rate cần điều kiện tổng request tối thiểu": 1 lỗi / 2 request = 50% nhưng không phải sự cố.

## 3. Trigger thật (bắt buộc ít nhất 1)

| Alert | Cách trigger | Chờ |
|---|---|---|
| 5xx | từ IP whitelist gọi `/boom` mỗi giây trong ~6 phút (script ngắn, tự dừng) | 5–10 phút tới khi Fired |
| CPU | test tải D19 (~10 phút) — đồng thời autoscale sẽ bật instance 2 | 10–15 phút |
| MySQL connections | mở nhiều kết nối đồng thời bằng script ngắn **hoặc** tạm hạ ngưỡng (qua PR) → trả ngưỡng sau | 5 phút |

Chụp:
1. Monitor → **Alerts** → alert trạng thái **Fired**.
2. Email nhận được (che địa chỉ).
3. Sau khi dừng: alert **Resolved** + email resolved.
4. Dashboard D21 cùng khoảng thời gian (thấy đỉnh 5xx/CPU).

## 4. `runbook.md` — cho alert nghiêm trọng nhất (5xx)

```
# Runbook — Alert 5xx rate
## Triệu chứng
- Email/alert "5xx rate" Sev1; người dùng thấy lỗi 5xx
## Xác nhận (≤ 5 phút)
1. Dashboard: failure rate, response time, thời điểm bắt đầu
2. KQL Q2 (tỷ lệ 5xx) và Q5 (lỗi mới nhất + stack)
3. /health production: 200 hay 503?
4. Có deploy gần đây? → run CD gần nhất, Activity log (swap)
5. Key Vault reference còn xanh? MySQL còn Ready? Firewall?
## Xử lý theo nguyên nhân
| Nguyên nhân | Dấu hiệu | Hành động |
| Bản deploy mới lỗi | lỗi bắt đầu ngay sau swap | swap ngược (Rollback) |
| DB không kết nối | /health 503, lỗi kết nối trong log | kiểm tra MySQL state, firewall vs outbound IPs, CPU MySQL |
| Mất secret | KV reference đỏ, app restart liên tục | kiểm tra role MI trên vault, apply lại |
| Quá tải | CPU cao, queue dài | xác nhận autoscale đã lên 2; giảm tải |
| Endpoint lỗi cố ý (/boom) | chỉ path /boom | xác nhận là test, ghi chú |
## Rollback
- Swap production ↔ staging (bản trước còn ở staging nếu chưa deploy đè)
- Kiểm tra /version = SHA cũ, failure rate về 0
- Không được: sửa tay cấu hình rồi quên đưa vào Terraform
## Escalate
- Khi nào: không xác định nguyên nhân sau 30 phút / rollback không hiệu quả / nghi lộ secret
- Liên hệ: mentor (kênh …)
- Gửi kèm: thời điểm bắt đầu, alert link, truy vấn đã chạy, hành động đã làm
## Sau sự cố
- Ghi timeline, nguyên nhân, action item → known-issues.md
```

Kiểm chứng runbook bằng cách **làm theo đúng từng bước** trong lúc trigger 5xx ở mục 3 — sửa những bước không làm được.

## 5. `evidence/M11.md`
Gom: dashboard (D21) · truy vấn log (D21) · 3 alert rule (screenshot/Terraform) · action group test · trigger thật (Fired + email + Resolved) · link runbook.

## Bẫy
- Log alert tính phí theo tần suất — 5 phút là đủ, không cần 1 phút.
- Metric alert chọn nhầm resource (Web App thay vì Plan cho CPU) → không bao giờ bắn.
- Alert bắn nhưng không có email → action group chưa gắn, hoặc email vào spam.
- Script `/boom` quên dừng → alert treo, log tăng.
- Alert rule bị destroy mỗi ngày → lịch sử alert mất; chụp bằng chứng ngay.

## Tự kiểm tra
1. Vì sao alert 5xx theo rate cần điều kiện số request tối thiểu?
2. Vì sao tách action group khỏi alert rule?
3. Bước nào trong runbook bạn thấy khó làm lúc 3 giờ sáng, sửa thế nào?

## Xong khi
- [ ] action group test OK · [ ] 3 alert bằng Terraform · [ ] ≥ 1 alert Fired thật + email + Resolved · [ ] `runbook.md` đã được đi thử · [ ] `evidence/M11.md` đầy đủ

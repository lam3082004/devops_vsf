# D25 — Demo 45 phút

**Luật:** live, chạy thật, **không slide**

## 1. Kịch bản (45 phút)

| Phút | Phần | Làm gì trên màn hình | Chứng minh |
|---|---|---|---|
| 0–3 | Mở đầu | README + `architecture.md` (2 sơ đồ) | bức tranh tổng |
| 3–8 | Trunk-based + CI chặn cái sai | mở PR có secret giả (đã chuẩn bị) → gitleaks đỏ → nút merge bị khoá · ruleset | M9 |
| 8–15 | CD + zero-downtime | chạy `poll-version` · merge PR xanh → CD → swap · log A→B, 0 non-200 | M10, M2 |
| 15–19 | Container + identity | ACR admin disabled · pull bằng MI · `/version` | M1 |
| 19–23 | DB + secret | `/items` POST/GET · KV reference xanh · firewall MySQL | M3, M4 |
| 23–28 | Gãy khi mất quyền | gỡ role MI khỏi KV → restart → app gãy → trả quyền → sống lại | M5 |
| 28–31 | IP whitelist | curl từ máy 200 · hotspot điện thoại 403 | M6 |
| 31–36 | Autoscale + alert | `/load` → CPU ↑ (chiếu metric) · `/boom` → alert 5xx → email · runbook | M7, M11 |
| 36–40 | Quan sát | Workbook · 2 truy vấn KQL · log JSON | M11 |
| 40–42 | Terraform | log destroy → apply (M8) · giải thích state/lock | M8 |
| 42–45 | Chi phí + bài học | Cost Analysis thật · 3 biện pháp · known-issues · 1–2 case AI sai | M7 |

Phần chờ lâu (CD, alert 5–10 phút, autoscale): **kích hoạt sớm**, nói phần khác trong lúc chờ, quay lại khi có kết quả. Ví dụ: bắt đầu `/boom` ở phút 8, alert sẽ tới quanh phút 20.

## 2. Checklist trước demo

**T−1 ngày**
- [ ] Chạy thử toàn bộ kịch bản, bấm giờ
- [ ] Chuẩn bị sẵn nhánh/PR: (1) secret giả, (2) thay đổi nhỏ để deploy
- [ ] Script: `poll-version`, `load`, `boom` sẵn trong `scripts/`
- [ ] Mở sẵn tab: repo, Actions, Portal (Web App, ACR, KV, MySQL, Alerts, Workbook, Cost Analysis), email
- [ ] Bằng chứng dự phòng trong `evidence/` (nếu live hỏng)

**T−60 phút**
- [ ] `make up` → CD deploy bản hiện tại → `/health` 200
- [ ] **IP nơi demo đã nằm trong whitelist** (IP phòng họp khác IP nhà!) → sửa biến → apply
- [ ] Điện thoại có 4G, hotspot hoạt động
- [ ] Alert rule đang bật, action group test OK
- [ ] Workbook có dữ liệu (gọi vài request trước)
- [ ] Không còn luật IP tạm, không còn alert treo

**T−5 phút**
- [ ] Tắt thông báo máy, phóng to chữ terminal/trình duyệt
- [ ] Không có secret/email cá nhân trên màn hình (password manager đóng)

## 3. Nếu hỏng giữa chừng
| Hỏng | Làm |
|---|---|
| CD chạy lâu/lỗi | nói nguyên nhân dự đoán, mở log run; chuyển phần khác; dùng log M2/M10 đã lưu |
| Alert chưa tới | tiếp tục, quay lại cuối; dự phòng screenshot lần trigger trước |
| Tự nhận 403 | IP đổi → sửa biến + apply (vừa demo cả quy trình) |
| Azure chậm | chuyển sang phần repo/CI trước |

Nguyên tắc: nói thật đang xảy ra gì, cho thấy cách chẩn đoán — đó cũng là kỹ năng vận hành.

## 4. Sau demo
- [ ] `make down` → `make check-empty` → Resources trống
- [ ] Screenshot Cost Analysis cuối cùng → cập nhật `cost-report.md`
- [ ] Ghi câu hỏi mentor hỏi + chỗ trả lời chưa tốt → `known-issues.md`
- [ ] Nhắc: credit/subscription hết hạn 15/10 → xoá bootstrap nếu không dùng nữa (sau khi mentor chấm)
- [ ] Chuyển plan sang `docs/plans/completed/`

## Xong khi
- [ ] chạy thử đủ kịch bản trong 45 phút · [ ] demo live xong · [ ] `make down` + Resources trống · [ ] cost report cập nhật · [ ] plan chuyển sang completed

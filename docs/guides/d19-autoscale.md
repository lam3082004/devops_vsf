# D19 — Autoscale · right sizing

**Cần:** D16 · **Chi phí:** có (thêm ~$0.1 khi chạy 2 instance) · **Bằng chứng:** phần autoscale trong `evidence/M7.md`

## Mục tiêu
Autoscale **max 2 instance** theo CPU, chứng minh 1 → 2 → 1 bằng test tải **ngắn**; quyết định tier bằng số đo.

## 1. Terraform: autoscale setting cho App Service Plan

| Thuộc tính | Giá trị |
|---|---|
| Target | App Service **Plan** (không phải Web App) |
| Capacity | default 1 · minimum 1 · **maximum 2** |
| Rule scale out | metric CPU Percentage của plan · trung bình · cửa sổ **5 phút** · **> 70%** → tăng 1 · cooldown 5 phút |
| Rule scale in | CPU trung bình · cửa sổ **10 phút** · **< 30%** → giảm 1 · cooldown 10 phút |
| Thông báo | email tới bạn (tuỳ chọn, giúp chụp bằng chứng) |

Ghi Decision: vì sao ngưỡng 70/30 và cửa sổ in dài hơn out (tránh flapping).

## 2. Test tải ngắn — script `scripts/load` (tự viết)
- Gửi song song N request `/load?seconds=60` lặp lại, **tổng thời gian tối đa ~8 phút**, rồi dừng hẳn.
- Chạy từ IP đã whitelist.
- Với 1 vCPU: 2–4 request song song là đủ đẩy CPU trên 70%.
- Ghi thời gian bắt đầu/kết thúc.

## 3. Quan sát và chụp
1. App Service Plan → **Metrics**: CPU Percentage + (nếu có) số instance, khung 30 phút → chụp khi thấy CPU vượt ngưỡng.
2. Web App → **Scale out** → **Run history**: sự kiện scale out 1→2 → chụp.
3. Dừng tải → chờ ~15–20 phút → sự kiện scale in 2→1 → chụp.
4. Trong lúc 2 instance: gọi `/version` vài lần — cùng SHA (hai instance cùng bản).

## 4. Right sizing
Thu thập trong một buổi có tải bình thường + lúc test tải:

| Chỉ số | Trung bình | Đỉnh |
|---|---|---|
| CPU % plan | | |
| Memory % plan | | |
| Response time `/items` | | |

So sánh lựa chọn — giá Linux, Southeast Asia, pay-as-you-go, tra Azure Retail Prices API ngày 2026-09-15 (giá có thể đổi, tra lại khi viết cost report):

| Tier | vCPU/RAM | Giá/giờ | Slot | Autoscale | Nhận xét |
|---|---|---|---|---|---|
| B1 | 1 / 1.75 GB | $0.018 | ❌ | ❌ | loại vì M2, M7 |
| S1 | 1 / 1.75 GB | $0.095 | ✅ | ✅ | đắt hơn P0V3, ít RAM hơn |
| **P0V3** | 1 / 4 GB | **$0.0915** | ✅ | ✅ | rẻ nhất có slot + autoscale |
| P0V4 | 1 / 4 GB | $0.0949 | ✅ | ✅ | khả dụng ở Southeast Asia, đắt hơn P0V3 một chút |

Kết luận tier + lý do → dùng trong `cost-report.md` (D20).

## Bẫy
- Scale theo metric của Web App thay vì Plan → rule không kích hoạt như mong đợi.
- Test tải kéo dài quên tắt → 2 instance cả buổi, alert CPU bắn liên tục.
- `/load` bị giới hạn `LOAD_MAX_SECONDS` → script gửi seconds lớn nhận 400, CPU không lên.
- Autoscale mất vài phút mới phản ứng (cửa sổ 5 phút + đánh giá định kỳ) — kiên nhẫn, đừng tăng tải thêm.
- Scale in sẽ dừng một instance → nếu có lỗi 5xx lúc đó → xem lại tắt êm.

## Tự kiểm tra
1. Vì sao max 2?
2. Flapping là gì, cấu hình nào của bạn chống nó?
3. Scale up và scale out khác gì, bạn đã dùng cái nào ở đâu?

## Xong khi
- [ ] autoscale bằng Terraform, max 2 · [ ] screenshot 1→2 và 2→1 · [ ] bảng right sizing + kết luận tier

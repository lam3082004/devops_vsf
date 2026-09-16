# D18 — Bằng chứng zero-downtime

**Cần:** D17 · **Chi phí:** có · **Bằng chứng:** `evidence/M2.md`, `evidence/raw/m2-*.log`

## Mục tiêu (M2)
Script poll `/version` 1 lần/giây trong lúc swap. Nộp **log thô**: **0 response non-200**, version đổi **A → B**.

## 1. Script `scripts/poll-version` — yêu cầu (tự viết)

| Yêu cầu | Chi tiết |
|---|---|
| Chu kỳ | 1 request/giây (không chờ request trước xong mới tính giây kế — hoặc ghi rõ nếu tuần tự) |
| Timeout mỗi request | 2–3 giây; **timeout ghi là lỗi** (`status=000`) |
| Mỗi dòng log | thời gian ISO có mili giây · mã HTTP · SHA trong body (hoặc `-`) · độ trễ ms |
| Đầu ra | vừa in màn hình vừa ghi file `evidence/raw/m2-<ngày>-<giờ>.log` |
| Dừng | Ctrl+C → in **tóm tắt**: tổng request · số non-200 · các SHA đã thấy · thời điểm thấy SHA mới đầu tiên · thời điểm cuối cùng thấy SHA cũ |
| Tham số | URL, file đầu ra |
| Không phụ thuộc | chỉ công cụ có sẵn trên máy (shell + curl, hoặc ngôn ngữ app) |

Ví dụ định dạng dòng:
```
2026-09-24T14:02:11.043+07:00 200 3f2a9c1 87ms
2026-09-24T14:02:12.041+07:00 200 3f2a9c1 91ms
2026-09-24T14:02:13.044+07:00 200 b71e0d4 140ms
```

## 2. Quy trình ghi bằng chứng
1. `make up` xong ít nhất 10 phút (app nóng). Máy chạy script ở **IP đã whitelist**.
2. Ghi SHA hiện tại A (`/version`).
3. Chuẩn bị PR thay đổi nhỏ, CI đã xanh.
4. **Bắt đầu script** → chờ 60 giây (baseline).
5. Merge PR → theo dõi CD.
6. Swap xong → để script chạy thêm **≥ 2 phút**.
7. Ctrl+C → lưu tóm tắt.

## 3. Đọc kết quả

| Quan sát | Nghĩa |
|---|---|
| 0 non-200, A…A → B…B | ✅ đạt |
| Vài dòng A/B xen kẽ quanh lúc swap | bình thường khi có nhiều instance/kết nối cũ — giải thích trong M2, vẫn đạt nếu 0 non-200 |
| Có 5xx/000 quanh lúc swap | chưa đạt → mục 4 |
| Không bao giờ thấy B | CD chưa swap / cache / nhầm URL |

## 4. Nếu có lỗi
| Triệu chứng | Hướng tìm |
|---|---|
| 503 ngay lúc swap | warm-up path/statuses (D17) |
| 502/000 vài giây sau swap | instance cũ bị dừng khi còn request → tắt êm SIGTERM (D4) |
| Lỗi khi instance restart | thời gian khởi động container, always on |
| 403 | IP máy đổi / IPv6 (D13) |

Sửa → PR → chạy lại toàn bộ quy trình → giữ **cả log thất bại** (ghi vào known-issues/M2 phần "lần thử trước").

## 5. `evidence/M2.md`
- Link PR, run CD, thời điểm bắt đầu/kết thúc swap (từ log CD hoặc Activity log).
- Tóm tắt script.
- 10 dòng quanh thời điểm chuyển A→B trích từ log.
- Đường dẫn file log thô đầy đủ (không chỉnh sửa).

## Tự kiểm tra
1. Vì sao timeout phải tính là lỗi?
2. Log thô có giá trị hơn screenshot ở điểm nào?
3. Nếu 2 instance đang chạy khi swap, log sẽ trông khác thế nào?

## Xong khi
- [ ] script trong repo · [ ] log thô: 0 non-200, A→B · [ ] `evidence/M2.md`

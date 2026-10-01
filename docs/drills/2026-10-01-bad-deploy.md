# Drill 2 — deploy bản lỗi → swap ngược · 2026-10-01

Kịch bản A của `docs/guides/d24-drill-finalize.md`. Postmortem không đổ lỗi. Claude soạn lỗi, tự gây và chẩn đoán
(người dùng chốt 30/09); lệnh swap ngược do người dùng chạy tay vì auto mode chặn Claude thao tác production.

Log thô: `evidence/raw/d24-drill2-watch.tsv` · `evidence/raw/d24-drill2-traffic-1.tsv` (GET `/items` 1 lần/giây) ·
`evidence/raw/d24-drill2-actions.log` · `evidence/raw/d24-drill2-agent-triage-*.md`. PR lỗi: #72 (`9f2c849`) ·
PR revert: #73 (`7c4b6ed`) · CD: `36827413210` (bản lỗi) và `36829181019` (revert).

## Tóm tắt

PR #72 thêm `int.Parse(limit!)` vào `GET /items`: gọi không có `limit` là ném `ArgumentNullException`. Test được
"sửa theo code" (thêm `limit=50`) nên **CI xanh 8/8**. Merge xong, **CD xanh**: cổng trước swap chỉ poll `/health`,
`/version` và `fe /api/health`, không đường nào đi qua `GET /items` không tham số. Production `be` trả 503 trong
12 phút 39 giây. Alert 5xx Fired 2 phút 17 giây sau lỗi đầu. Swap ngược slot `be` mất 39 giây, sau đó PR revert
đưa bản tốt lên cả 2 slot. `fe` **không** bị ảnh hưởng vì luôn gửi `limit`.

## Tác động

| | |
|---|---|
| `be` `GET /items` không có `limit` → **503** `database_unavailable` | 07:00:20 → 07:12:59Z = **12 phút 39 giây** |
| `be` `/items?limit=…`, `/health`, toàn bộ `fe` | không ảnh hưởng (200) |
| Traffic thử | xem `evidence/raw/d24-drill2-traffic-1.tsv` |

## Timeline (UTC)

| Thời điểm | Sự kiện | Phát hiện bởi | Hành động |
|---|---|---|---|
| (trước) | PR #72: CI **8/8 xanh** | — | — |
| 06:55:36 | **T0**: merge #72 → CD `36827413210` | — | — |
| 06:59:39 | CD swap `be` Started | Activity Log | — |
| 07:00:20 | `/items` 5xx đầu tiên (swap chuyển dần traffic) | traffic | — |
| 07:01:03 | swap `be` Succeeded · 07:02:45 swap `fe` Succeeded · **CD kết thúc success** | — | — |
| **07:02:37** | **`alert-vsf-5xx-rate` Fired** | alert + email | — |
| ~07:05 | agent `mode=triage`: `db_error` `Value cannot be null. (Parameter 's')` ×71 từ 07:00, trùng SHA mới `9f2c849` | agent | kết luận: deploy lỗi, swap ngược |
| 07:12:20 | swap ngược slot `be` Started (người dùng chạy tay) | — | `az webapp deployment slot swap` |
| **07:12:59** | lỗi cuối · 07:13:38 watcher 200 · production `be` = `a3bccf4` | watcher | — |
| 07:14:15 | merge PR revert #73 → CD `36829181019` success | — | — |
| ~07:20 | production `be` = `7c4b6ed`, staging = `a3bccf4`: **cả 2 slot là bản tốt** | — | — |
| **07:38:41** | alert Resolved (25 phút 42 giây sau lỗi cuối) | alert + email | — |

## Số đo

| | Tính từ | Giá trị |
|---|---|---|
| TTD bằng alert | lỗi đầu 07:00:20 → Fired 07:02:37 | **2 phút 17 giây** |
| Chẩn đoán | Fired → kết luận "swap ngược" (~07:05) | ~2–3 phút |
| Chờ người chạy lệnh swap | ~07:05 → 07:12:20 | ~7 phút (auto mode chặn Claude, phải nhờ người dùng) |
| Bản thân swap ngược | Started 07:12:20 → lỗi cuối 07:12:59 | **39 giây** |
| **RTO** (lỗi đầu → hồi phục) | 07:00:20 → 07:12:59 | **12 phút 39 giây** |
| Merge revert → cả 2 slot sạch | 07:14:15 → ~07:20 | ~6 phút |

Nếu người trực có sẵn quyền swap và runbook trong tay, RTO ước tính ≈ TTD + chẩn đoán + swap ≈ **5–6 phút**. Phần
lớn RTO đo được là thời gian chờ người.

## Nguyên nhân gốc

1. **Cổng CD không kiểm hành vi nghiệp vụ.** Poll staging chỉ gọi `/health`, `/version`, `fe /api/health`. Một
   regression ở route nghiệp vụ đi thẳng qua.
2. **Test bị sửa theo code.** CI chỉ chặn được những gì test khẳng định; PR đổi test để khớp lỗi, review không bắt.
3. **Phân loại lỗi sai** (phát hiện phụ): `DatabaseExceptionFilter` biến **mọi** exception chưa xử lý thành
   `503 database_unavailable` và log `event=db_error`. Lỗi code trông y hệt sự cố DB của drill 1 cùng ngày; chỉ chuỗi
   `Value cannot be null` và mốc trùng SHA mới mới chỉ ra đúng hướng.

## Làm tốt

- Alert bắn nhanh (2 phút 17 giây), email tới thật (người dùng nhận cả Fired/Resolved).
- Watcher ghi SHA mỗi 30 giây: thấy ngay `9f2c849` lên lúc 07:00:36, nối nguyên nhân với deploy trong 1 dòng.
- Swap ngược đúng như runbook: 39 giây, không cần build lại. Slot staging giữ bản trước nên rollback không phụ thuộc
  ACR hay CI.
- PR revert làm sạch cả 2 slot; không để bản lỗi nằm chờ ở staging cho lần swap sau.

## Chưa tốt

- **CI và CD đều xanh trên một bản làm hỏng production.**
- Agent đọc sự cố liệt kê lỗi dưới nhãn `db_error`: người trực phải tự đọc chuỗi exception mới không đi nhầm sang DB.
- Claude không tự swap được (auto mode): trong thực tế, người trực phải có quyền và lệnh sẵn. 7 phút chờ là chi phí
  thật của việc thiếu quyền đúng lúc.
- Bảng exception App Insights trong báo cáo agent không có `ArgumentNullException`: filter đã "xử lý" nên exception
  không được ghi như exception chưa xử lý.

## Action items

| # | Việc | Loại | Trạng thái |
|---|---|---|---|
| 1 | CD: smoke test `GET /items` (không tham số và có `limit`) trên **staging** trước swap, đỏ → không swap | sửa | PR DevSecOps (người dùng duyệt 01/10) |
| 2 | `DatabaseExceptionFilter` chỉ bắt `MySqlException`/`DbException`; exception khác → 500 `internal_error` + log `event=unhandled_error` | đề xuất | chưa làm, đổi hành vi app |
| 3 | Review PR: test đổi kỳ vọng cùng lúc với code là tín hiệu cần hỏi lại (thêm vào `.github/pull_request_template.md`) | đề xuất | chưa làm |
| 4 | Runbook bước 5 "Có deploy gần đây không?" + dòng "Bản deploy mới lỗi → Rollback" | đã có | ✅ drill đi đúng đường này; thêm cảnh báo `db_error` có thể là lỗi code vào dòng "DB không kết nối" (PR tài liệu D24) |

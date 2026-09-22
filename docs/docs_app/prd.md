# PRD — OpsBoard

Liên quan: [brief](brief.md) · [wire-frame](wire-frame.md) · [api-spec](api-spec.md) · [database-schema](database-schema.md)

## 1. Từ vựng
| Từ | Nghĩa |
|---|---|
| Ticket | Một lỗi/đầu việc cần theo dõi. Trong API là `/items`. |
| Reporter | Người tạo ticket. |
| Assignee | Người đang xử lý (có thể trống). |
| Actor | Người thực hiện một thao tác (tên nhập ở giao diện, gửi qua header `X-User-Name`). |

## 2. Quy tắc nghiệp vụ

**Mức độ (`severity`):** `low` · `medium` · `high` · `critical`. Mặc định `medium`.

**Phân loại (`category`):** `infra` · `app` · `database` · `network` · `security` · `other`. Mặc định `other`.

**Trạng thái (`status`) và chuyển trạng thái hợp lệ:**

| Từ \ Sang | open | in_progress | resolved | closed |
|---|---|---|---|---|
| open | — | ✔ | ✘ | ✘ |
| in_progress | ✔ | — | ✔ | ✘ |
| resolved | ✘ | ✔ (mở lại) | — | ✔ |
| closed | ✘ | ✘ | ✘ | — |

- `closed` là trạng thái cuối. Chuyển sai → lỗi `409 invalid_transition`.
- Sang `resolved` thì ghi `resolved_at`; mở lại thì xoá `resolved_at`.
- Sang `in_progress` mà chưa có assignee → gán actor làm assignee.
- Ghi 1 dòng lịch sử cho **mọi trường thay đổi** (không chỉ status/assignee/severity): 7 `action` —
  `created`, `status_changed`, `assignee_changed`, `severity_changed`, `category_changed`, `title_changed`,
  `description_changed` (xem `api-spec.md`).

**Ràng buộc dữ liệu:** `title` 1–200 ký tự (sau trim) · `description` ≤ 5000 · `assignee`/`reporter` 1–50 ·
`comment.body` 1–2000. Ký tự thừa bị từ chối, không tự cắt.

## 3. User story và tiêu chí chấp nhận

**US-01 — Nhập tên để bắt đầu**
Là thành viên, tôi nhập tên một lần để mọi thao tác ghi tên tôi.
- Chưa có tên → mọi thao tác ghi bị chặn, giao diện hỏi tên. Tên 1–50 ký tự, lưu ở trình duyệt.

**US-02 — Tạo ticket**
- Bắt buộc `title`; các trường còn lại có mặc định. Tạo xong ticket ở `open`, reporter = actor.
- Thiếu/dài quá → báo lỗi ngay trên form, không mất dữ liệu đã nhập.

**US-03 — Xem bảng kanban**
- 4 cột theo trạng thái, mỗi thẻ hiện tiêu đề, severity, assignee, tuổi ticket.
- Ticket `critical` đang mở nổi bật hơn thẻ khác.
- Kéo thẻ sang cột khác = đổi trạng thái; chuyển không hợp lệ → thẻ về chỗ cũ kèm thông báo lý do.

**US-04 — Danh sách, lọc, tìm**
- Lọc theo status, severity, category, assignee; tìm theo tiêu đề. Phân trang, tối đa 100 dòng/trang.

**US-05 — Xem và cập nhật chi tiết**
- Sửa tiêu đề, mô tả, severity, category, assignee. Xem lịch sử thay đổi theo thời gian.

**US-06 — Bình luận**
- Thêm bình luận vào ticket; hiện theo thứ tự thời gian, kèm tên và giờ. Không sửa/xoá bình luận.

**US-07 — Thống kê**
- Tổng ticket, số theo status và severity, số ticket `critical` đang mở, thời gian xử lý trung bình (phút, tính từ ticket `resolved`).

**US-08 — Chịu lỗi hạ tầng**
- Backend lỗi/DB mất → giao diện hiện thông báo lỗi rõ ràng, không trắng trang; thử lại được.

## 4. Yêu cầu phi chức năng
| Nhóm | Yêu cầu |
|---|---|
| Hiệu năng | p95 `/items` < 500 ms với ≤ 10.000 ticket |
| Sẵn sàng | Deploy không gián đoạn (swap); `/health` = 200 mới nhận traffic |
| An toàn | Truy cập chỉ từ IP whitelist; secret ở Key Vault; SQL tham số hoá; mọi input được validate ở backend |
| Quan sát | Log JSON 1 dòng/request có `trace_id`; trace end-to-end trình duyệt → Next.js → .NET → MySQL |
| Khả năng dùng | Dùng được trên màn hình ≥ 1280 px; phím tab/enter dùng được cho form |
| Vận hành | Dựng lại từ Terraform không thao tác tay; rollback bằng swap ngược |

## 5. Hook Jev (thiết kế, chưa làm)
`TriageProvider` nhận `(title, description)` trả `(severity, category, confidence)`. Bản đầu là bản luật đơn giản
(từ khoá). Bản Jev thay thế mà không đổi API. Quy tắc: timeout ngắn, lỗi/độ tin cậy thấp → dùng mặc định,
không bao giờ làm ticket tạo thất bại. Key ở Key Vault. Chưa dùng khi chưa được mentor duyệt.

## 6. Ngoài phạm vi
Xem brief mục 5.

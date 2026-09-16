# D15 — Cross-review lần 1

**Cần:** bạn intern kia đã có repo · **Chi phí:** 0 · **Deliverable:** `review-<tên bạn kia>.md` (trong repo của bạn)

## Mục tiêu
Đọc hạ tầng của người khác bằng con mắt reviewer: tìm chỗ **sai, không an toàn, không tái lập được, không có bằng chứng** — và nhận lại review cho repo mình.

## 1. Chuẩn bị
- Hẹn thời điểm cả hai có commit ổn định trên `main`, trao đổi link repo (quyền đọc).
- Không cần chạy hạ tầng của bạn kia (không có quyền subscription của họ) — review bằng đọc code, plan artifact, CI runs, evidence.

## 2. Checklist review

| Nhóm | Câu hỏi | Mức |
|---|---|---|
| **Secret** | Có secret/mật khẩu/key trong code, app settings, log, lịch sử commit không? File state/plan nhị phân có bị commit/upload không? | Chặn |
| **Quyền** | Role nào gán ở scope quá rộng (subscription thay vì resource)? CI có Owner/Contributor không cần thiết? | Chặn |
| **Mạng** | MySQL "allow Azure services"? Slot/SCM thiếu access restriction? | Chặn |
| **M1/M4** | ACR admin tắt? Pull bằng user-assigned MI? KV reference có identity? | Chặn |
| **Tái lập** | Có thao tác tay nào ngầm (README có bước Portal)? destroy → apply đã có log? Vault purge? | Chặn |
| **CI gate** | Các job có required không? Có "continue on error"? gitleaks quét đủ lịch sử? | Chặn |
| **Trunk-based** | Nhánh sống > 2 ngày? Có push thẳng main? PR có mục AI usage? | Không chặn |
| **Terraform** | Phiên bản ghim? Lock file commit? `depends_on` lạm dụng? Tên toàn cầu có hậu tố? | Không chặn |
| **Chi phí** | Tier, backup retention, geo backup, auto-grow, Log Analytics retention | Không chặn |
| **Bằng chứng** | Evidence là log thô/screenshot thật hay chỉ lời mô tả? | Không chặn |

## 3. Viết `review-<tên>.md`

```
# Review repo <link> — lần 1 — <ngày> — commit <sha>
## Tóm tắt (3 dòng)
## Phát hiện
| # | Mức (Chặn/Không chặn) | File:dòng | Vấn đề | Tình huống gây lỗi | Đề xuất |
## Điểm làm tốt (≥ 2)
## Câu hỏi cho tác giả
```

Quy tắc: mỗi phát hiện có **tình huống cụ thể** (ví dụ "destroy → apply sẽ lỗi vì vault soft-deleted"), không ghi chung chung "nên cải thiện bảo mật".

Nộp qua PR vào repo của bạn; gửi link cho bạn kia.

## 4. Nhận review
1. Mỗi phát hiện "Chặn" → một issue hoặc một dòng trong plan.
2. Sửa qua PR riêng, tham chiếu phát hiện số mấy.
3. Phát hiện không đồng ý → trả lời lý do trong issue, không lờ đi.

## 5. Dọn sau review
- Chạy lại `make down` → `make up` sau các thay đổi tuần 3 → cập nhật log `evidence/M8.md` (lần 2).
- Cập nhật `README.md` bản nháp: prerequisite · biến cần set · `make up` / `make down` · teardown.

## Tự kiểm tra
1. Phát hiện nào của bạn kia bạn cũng đang mắc?
2. Phát hiện nào khó thấy nhất nếu chỉ đọc code (cần xem plan hoặc CI run)?

## Xong khi
- [ ] `review-<tên>.md` merged · [ ] phát hiện "Chặn" trong repo mình đã có PR sửa hoặc lý do · [ ] M8 lần 2 · [ ] README nháp

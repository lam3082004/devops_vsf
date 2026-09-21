# D23 — Agent giới hạn quyền · cross-review lần 2

**Cần:** D22 · **Chi phí:** ít · **Deliverable:** bài agent (theo đề mentor), `review-<tên>.md` lần 2

> Đề bài `topic.md` chỉ ghi "bài agent giới hạn quyền" — **chưa có đặc tả**. Hỏi mentor nội dung cụ thể trước. Phần dưới là khung chuẩn bị để làm bất kỳ biến thể nào.

## Phần A — Agent giới hạn quyền

### 1. Xác định agent và việc nó được làm
Ví dụ hợp lý cho dự án (chọn theo đề mentor):

| Agent | Việc | Không được làm |
|---|---|---|
| Agent đọc sự cố | đọc log/metric, tóm tắt nguyên nhân 5xx | sửa cấu hình, đọc secret, deploy |
| Agent vận hành hẹp | restart Web App / swap ngược theo runbook | tạo/xoá resource, đổi quyền, đọc DB |
| AI coding agent trong repo | đọc code, chạy lint/test, mở PR | push `main`, đọc `.env`, chạy `apply`/`destroy` |

### 2. Thiết kế quyền (bảng bắt buộc có trong bài nộp)

| Lớp | Danh tính | Quyền cấp | Scope | Vì sao đủ | Vì sao không rộng hơn |
|---|---|---|---|---|---|
| Azure | user-assigned MI hoặc service principal riêng cho agent | ví dụ Log Analytics Reader | workspace | | |
| Azure | … | ví dụ Website Contributor | chỉ Web App | | |
| GitHub | token fine-grained / GitHub App | contents read, pull requests write | chỉ repo này | | |
| Máy local | cấu hình quyền của công cụ agent (allowlist lệnh, cấm lệnh phá huỷ) | | | | |

Nguyên tắc: một agent một danh tính · quyền đọc mặc định · scope hẹp nhất · không có quyền cấp quyền · không có quyền data plane Key Vault · token ngắn hạn (OIDC) thay vì secret dài hạn.

### 3. Tạo bằng Terraform (phần Azure)
Danh tính + role assignment đúng bảng trên, nằm trong stack phù hợp vòng đời (bootstrap nếu agent dùng lâu dài).

### 4. Chứng minh ngược (quan trọng nhất)

| Thử | Mong đợi | Bằng chứng |
|---|---|---|
| Agent làm việc được phép (ví dụ chạy KQL) | thành công | output |
| Đọc secret Key Vault | **Forbidden** | lỗi nguyên văn |
| Xoá/tạo resource | **AuthorizationFailed** | lỗi nguyên văn |
| Gán role cho chính nó | **thất bại** | lỗi nguyên văn |
| (Coding agent) push thẳng `main` / chạy lệnh bị cấm | bị ruleset / cấu hình chặn | output |

### 5. Rủi ro còn lại
Ghi 3–5 dòng: agent vẫn có thể gây hại gì trong quyền được cấp (ví dụ restart liên tục gây gián đoạn; đọc log có thể chứa dữ liệu nhạy cảm nếu app log sai) và cách giảm.

## Phần B — Cross-review lần 2
Dùng lại checklist D15, thêm các mục tuần 4–5:

| Nhóm | Câu hỏi |
|---|---|
| CD | Nhánh khác deploy được không? Tag `latest`? Luật IP tạm có luôn được xoá? |
| Zero-downtime | Log M2 là log thô thật? Có non-200 bị bỏ qua? |
| Autoscale | max 2? Rule chống flapping? |
| Monitoring | Dashboard dùng App Insights (trái đề)? Alert có trigger thật? Runbook làm theo được không? |
| Cost | Số thật hay ước tính? 3 biện pháp có bằng chứng? |
| Phát hiện lần 1 | Đã sửa chưa? |

`review-<tên>.md` lần 2 cùng định dạng D15, thêm mục "Theo dõi phát hiện lần 1".

## Tự kiểm tra
1. Vì sao mỗi agent cần danh tính riêng thay vì dùng chung danh tính CI deploy?
2. Quyền đọc log có thể thành rủi ro dữ liệu thế nào?

## Xong khi
- [ ] bảng thiết kế quyền · [ ] ≥ 3 chứng minh ngược có lỗi nguyên văn · [ ] rủi ro còn lại · [ ] review lần 2 merged

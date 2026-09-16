# D14 — CI đầy đủ + bằng chứng đỏ

**Cần:** D6, D5, câu trả lời **Q4** (Trivy unfixed) · **Chi phí:** 0 · **Bằng chứng:** `evidence/M9.md`

> Đề: "Chứng minh cốt lõi của M9 không phải pipeline chạy xanh mà là **pipeline chặn được cái sai**."

## 1. Các job trong `ci.yml` (chạy trên PR, không deploy gì)

| Job | Làm gì | Đỏ khi |
|---|---|---|
| `gitleaks` | quét toàn bộ lịch sử PR | có secret |
| `lint` | linter của ngôn ngữ app | vi phạm lint |
| `test` | unit test | test fail |
| `terraform` | fmt kiểm tra · validate | sai format / cấu hình |
| `terraform-plan` | plan → artifact text (D9) | plan lỗi |
| `docker-build` | build image với SHA của PR, **không push** | build fail |
| `trivy` | scan image vừa build (cùng job với build hoặc truyền image qua artifact) | có CVE theo chính sách Q4 |

Thiết lập chung:
- Quyền token tối thiểu (đọc nội dung; plan cần thêm id-token).
- Action bên thứ ba ghim phiên bản/commit SHA.
- Nhóm đồng thời theo PR, huỷ lần chạy cũ khi có commit mới.
- Tên job **ổn định** (đổi tên = phải sửa required checks).

## 2. Trivy: đạt "không còn CVE"
1. Chính sách (theo Q4): mức độ nào làm đỏ · có bỏ qua CVE chưa có bản vá không.
2. Nếu còn CVE: đổi base image, cập nhật thư viện app, build lại → scan lại.
3. Nếu buộc phải bỏ qua một CVE: file bỏ qua có **mã CVE + lý do + ngày xem lại** — và ghi `known-issues.md`.
4. Cache database của Trivy để CI không tải lại mỗi lần (và không đỏ vì mạng).
5. Không bật "tiếp tục khi lỗi" cho bước scan.

## 3. Ruleset
Settings → Rules → `protect-main` → Required status checks: thêm **tất cả** job ở mục 1. Chụp màn hình.

## 4. Bằng chứng đỏ (M9)

| # | PR thử | Mong đợi | Chụp |
|---|---|---|---|
| 1 | Cắm chuỗi secret **giả** | `gitleaks` đỏ · nút merge bị khoá | tab Checks + khung merge |
| 2 | Dockerfile hỏng (ví dụ lệnh sai) | `docker-build` đỏ | |
| 3 | Test cố tình fail | `test` đỏ | |
| 4 | Terraform sai format | `terraform` đỏ | |
| 5 | (tuỳ chọn) base image cũ có CVE | `trivy` đỏ | |
| 6 | Với một PR đang đỏ: **thử bấm merge** | GitHub từ chối — không có nút merge hoặc báo "Required statuses must pass" | **bắt buộc chụp** |

Sau khi chụp: đóng PR, xoá nhánh, kiểm tra secret giả không nằm trên `main`.

Và một PR **xanh toàn bộ** → merge → chụp (đối chứng).

## 5. `evidence/M9.md`
Bảng mục 4 + link từng run + screenshot + danh sách required checks + chính sách Trivy.

## Bẫy
- `docker-build` và `trivy` ở hai job khác nhau nhưng không truyền image → Trivy scan image khác (hoặc kéo từ Internet).
- Trivy scan **thư mục source** thay vì **image** → không thấy CVE của OS package.
- Secret giả quá "giả" (không khớp mẫu) → gitleaks không bắt → tưởng CI hỏng. Dùng mẫu từ test fixtures của gitleaks.
- Admin bypass còn bật → merge được khi đỏ.
- Required check chỉ chạy khi thay đổi đường dẫn nhất định → PR không đụng đường dẫn đó bị kẹt "waiting". Tránh lọc theo đường dẫn cho job required.

## Tự kiểm tra
1. Fail-closed nghĩa là gì với bước scan?
2. Vì sao build image trong CI mà không push?
3. Nếu hôm nay xanh, tuần sau Trivy đỏ mà code không đổi — xử lý thế nào?

## Xong khi
- [ ] 7 job, tất cả required · [ ] 0 CVE theo chính sách · [ ] 6 bằng chứng đỏ + 1 xanh · [ ] `evidence/M9.md`

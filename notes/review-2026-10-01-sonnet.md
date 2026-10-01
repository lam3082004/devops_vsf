# Review độc lập D1–D24 (trừ D15, D25) — sub-agent Claude Sonnet, 2026-10-01

Người dùng yêu cầu: "viết prompt cho sub-agent model Sonnet review lại hết 25 day (trừ day 15 và day 25)". Prompt:
review **chỉ đọc**, không chạm Azure, không đọc `*.tfvars`, xếp loại từng bài + M1–M11, phát hiện P0–P3 có
`file:dòng`. Review trên `main` = `85d9ef0` (sau #75). Bản dưới là tóm tắt **kèm trạng thái xử lý**; IP egress
công ty mà báo cáo gốc chép lại đã được che (chính là phát hiện P2-8).

## Kết luận của reviewer

- **Không P0** (gitleaks 164 commit sạch; `*.tfstate`/`*.tfvars` không tracked).
- Sẵn sàng nộp: **khá, chưa sạch**. Bằng chứng chạy thật dày, run id đều tồn tại và khớp. Reviewer đếm lại từ log
  thô: M2 0 non-200 (774/774, 662/662, 649/649, 636/636); drill 1 MTTR 06:20:03→06:31:01; drill 2 RTO 07:00:20→07:12:59.
- Test local: `be` 142 pass / 12 skip / 0 fail · lint `be`, `fe` sạch · `fe` 14/14.
- Xếp loại: ĐẠT — D2, D4, D7–D9, D11–D13, D16, D17, D19, D21; ĐẠT MỘT PHẦN — D3, D5, D6, D10, D14, D18, D20, D22,
  D23, D24; KHÔNG KIỂM ĐƯỢC — D1 (ảnh mất). M1, M3–M7, M10: ĐẠT · M2, M8, M9, M11: ĐẠT MỘT PHẦN · S1 ĐẠT · S2, S3
  chưa làm.

## Phát hiện và xử lý

| # | Phát hiện | Xử lý |
|---|---|---|
| P1-1 | M9 thiếu 2 screenshot đề đòi (PR đỏ, merge bị khoá) | **người dùng chụp** (dùng lại PR #33/#34) |
| P1-2 | M11 dẫn ảnh email `evidence/d24/screenshots/…` không tồn tại | ✅ sửa chữ: "người dùng xác nhận, ảnh chưa lưu"; **người dùng lưu 2 ảnh** đã gửi trong phiên |
| P1-3 | M8 chưa destroy → apply hạ tầng hiện tại | đã ghi "Chưa xong" #7; cần gỡ PoC rồi `make down` → `make up` (người dùng quyết) |
| P1-4 | AI-OFF tuần 1 lệch: PR #1 tự khai Claude sinh Dockerfile (D5) + CI (D6); `ai-failure-log` #1, #2 cho thấy AI đưa lệnh `az` ở D3 — chưa ghi nhận ở đâu | **chờ người dùng quyết** cách ghi (known-issues hoặc hỏi mentor) |
| P1-5 | Không có `review-<tên>.md` × 2 | đã ghi trung thực ("Chưa xong" #6) |
| P2-1 | `id-gh-deploy` có Blob Data Contributor trên state dù CD không chạy Terraform | đề xuất xoá (đổi quyền, cần apply — chưa làm) |
| P2-2 | `id-gh-plan` (subject `pull_request`) có lease state, đọc secret DB, Reader cả subscription; README ghi "chỉ đọc" | ✅ sửa README; thu hẹp quyền là đề xuất (chưa làm) |
| P2-3 | App dùng tài khoản admin MySQL | đề xuất user DB riêng (chưa làm) |
| P2-4 | Semgrep không parse `ci.yml`/`cd.yml`, bước dùng `\|\| true` không kiểm `.errors` | đã ghi #32; đề xuất kiểm `.errors` trừ 2 lỗi parse đã biết (chưa làm) |
| P2-5 | test-report #17 vẫn ghi "chạy thử local" dù CD thật đã chạy | ✅ ghi run id + `evidence/devsecops.md` |
| P2-6 | `DatabaseExceptionFilter` gắn `database_unavailable` cho mọi exception | action item drill 2 (chưa làm, đổi hành vi app) |
| P2-7 | Free Trial và `.trivyignore` cùng hết hạn 15/10 | Q5 mentor; theo dõi |
| P2-8 | IP egress công ty (`104.30.x.x`, nhãn wifi công ty) nằm trong `evidence/M2.md`, `M6.md`, `notes/d17.md` — trái luật "không dữ liệu công ty" | **chờ người dùng quyết** (che trong file hiện tại; lịch sử git vẫn còn) |
| P2-9 | Môi trường chạy liên tục từ 24/09, `cost-report.md` dừng ở 28/09 | cập nhật chi phí trước D25 |
| P2-10 | App Insights bật dù M11 ghi "không enable App Insight" (Q1 chưa trả lời) | chờ mentor Q1 |
| P2-11 | "Clone mới" D24 cùng máy, cùng `az login`, state lấy từ bản sao local | đã ghi giới hạn ở `evidence/M8.md` |
| P2-12 | Tài liệu cũ: plan header/số case, known-issues "Chưa xong" #1/#2/#4, M9 "8 job", dependabot "8 check", README thiếu `drift.yml`, #32 mục 3 | ✅ sửa hết |
| P2-13 | 5 PR Dependabot mở, #79 (eslint 10) đỏ CI | ✅ Dependabot bỏ qua bản major cho npm; 5 PR chờ người duyệt |
| P3-1 | Định danh Azure (subscription/tenant/client id) trong evidence/plan | không phải credential; giữ |
| P3-2 | `infra/bootstrap/terraform.tfstate*` quyền 664 | ✅ `chmod 600` (local) |
| P3-3 | CI không chặn khi 12 test MySQL bị skip | đề xuất |
| P3-4 | Bảng 8 case tiêu biểu thiếu cột "AI sinh gì", "cách sửa" | có trong bảng đầy đủ (link) |
| P3-5 | Job plan CI khi môi trường tắt chỉ plan pha 1 | đã ghi trong job summary |
| P3-6 | comment `nosemgrep` đoạn `set` ghi nhầm `where.Add` | ✅ sửa |

## Không kiểm được (theo reviewer)

Trạng thái Azure thật (cấm `az`/`plan`), nội dung ảnh, `terraform.tfvars`, email có tới không (không có ảnh),
câu trả lời mentor Q1/Q3/Q5, 7 câu GATE D10 trả lời miệng, ảnh D1.

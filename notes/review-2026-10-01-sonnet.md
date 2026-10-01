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
| P1-1 | M9 thiếu 2 screenshot đề đòi (PR đỏ, merge bị khoá) | ✅ ảnh gitleaks đỏ (#85); ảnh "merge bị khoá" **chụp lúc chạy thử D25** (`notes/d25-prep.md` mục 2) |
| P1-2 | M11 dẫn ảnh email `evidence/d24/screenshots/…` không tồn tại | ✅ sửa chữ: "người dùng xác nhận, ảnh chưa lưu"; **người dùng lưu 2 ảnh** đã gửi trong phiên |
| P1-3 | M8 chưa destroy → apply hạ tầng hiện tại | đã ghi "Chưa xong" #7; cần gỡ PoC rồi `make down` → `make up` (người dùng quyết) |
| P1-4 | AI-OFF tuần 1 lệch: PR #1 tự khai Claude sinh Dockerfile (D5) + CI (D6); `ai-failure-log` #1, #2 cho thấy AI đưa lệnh `az` ở D3 — chưa ghi nhận ở đâu | ✅ người dùng chốt 02/10: ghi nhận thật → `known-issues.md` #34 |
| P1-5 | Không có `review-<tên>.md` × 2 | đã ghi trung thực ("Chưa xong" #6) |
| P2-1 | `id-gh-deploy` có Blob Data Contributor trên state dù CD không chạy Terraform | đề xuất xoá (đổi quyền, cần apply — chưa làm) |
| P2-2 | `id-gh-plan` (subject `pull_request`) có lease state, đọc secret DB, Reader cả subscription; README ghi "chỉ đọc" | ✅ sửa README; thu hẹp quyền là đề xuất (chưa làm) |
| P2-3 | App dùng tài khoản admin MySQL | đề xuất user DB riêng (chưa làm) |
| P2-4 | Semgrep không parse `ci.yml`/`cd.yml`, bước dùng `\|\| true` không kiểm `.errors` | ✅ 02/10: bỏ `\|\| true`, cổng đỏ khi `.errors` có lỗi ngoài 2 lỗi parse đã biết (thử với JSON thật + JSON chèn lỗi) |
| P2-5 | test-report #17 vẫn ghi "chạy thử local" dù CD thật đã chạy | ✅ ghi run id + `evidence/devsecops.md` |
| P2-6 | `DatabaseExceptionFilter` gắn `database_unavailable` cho mọi exception | action item drill 2 (chưa làm, đổi hành vi app) |
| P2-7 | Free Trial và `.trivyignore` cùng hết hạn 15/10 | Q5 mentor; theo dõi |
| P2-8 | IP egress công ty (`104.30.x.x`, nhãn wifi công ty) nằm trong `evidence/M2.md`, `M6.md`, `notes/d17.md` — trái luật "không dữ liệu công ty" | ✅ 02/10: che IP + nhãn wifi trong 10 file chữ và ảnh M6; quét thêm 67 ảnh → che email header Portal (26 ảnh D2/D5) và tab công cụ nội bộ (7 ảnh D11). Lịch sử git còn → `known-issues.md` #35 |
| P2-9 | Môi trường chạy liên tục từ 24/09, `cost-report.md` dừng ở 28/09 | ✅ 01/10: `cost-report.md` số Cost Management API ($19,38 `rg-vsf-dev`) |
| P2-10 | App Insights bật dù M11 ghi "không enable App Insight" (Q1 chưa trả lời) | chờ mentor Q1 |
| P2-11 | "Clone mới" D24 cùng máy, cùng `az login`, state lấy từ bản sao local | đã ghi giới hạn ở `evidence/M8.md` |
| P2-12 | Tài liệu cũ: plan header/số case, known-issues "Chưa xong" #1/#2/#4, M9 "8 job", dependabot "8 check", README thiếu `drift.yml`, #32 mục 3 | ✅ sửa hết |
| P2-13 | 5 PR Dependabot mở, #79 (eslint 10) đỏ CI | ✅ Dependabot bỏ qua bản major cho npm; 5 PR chờ người duyệt |
| P3-1 | Định danh Azure (subscription/tenant/client id) trong evidence/plan | không phải credential; giữ |
| P3-2 | `infra/bootstrap/terraform.tfstate*` quyền 664 | ✅ `chmod 600` (local) |
| P3-3 | CI không chặn khi 12 test MySQL bị skip | **không cần sửa**: đã có từ #24 — `CiEnvironmentTests` đỏ nếu CI thiếu `TEST_DB_HOST`; CI run `36884596733`: 159 pass, **0 skipped** |
| P3-4 | Bảng 8 case tiêu biểu thiếu cột "AI sinh gì", "cách sửa" | có trong bảng đầy đủ (link) |
| P3-5 | Job plan CI khi môi trường tắt chỉ plan pha 1 | đã ghi trong job summary |
| P3-6 | comment `nosemgrep` đoạn `set` ghi nhầm `where.Add` | ✅ sửa |

## Không kiểm được (theo reviewer)

Trạng thái Azure thật (cấm `az`/`plan`), nội dung ảnh, `terraform.tfvars`, email có tới không (không có ảnh),
câu trả lời mentor Q1/Q3/Q5, 7 câu GATE D10 trả lời miệng, ảnh D1.

## Vòng 2 — review sub-agent Sonnet 02/10 (nhánh `chore/d25-prep`, chuẩn bị D25)

Không P0. Đã sửa: P1-1 `demo-preflight.sh` FAIL giả khi 1 request chậm (thêm thử lại 2 lần, `--max-time 15`; kiểm alert theo
tên; tự `cd` về gốc repo; báo khi `.trivyignore` không có hạn) · P1-2 **IP nhà** đầy đủ còn trong `evidence/M6.md`,
`notes/d2.md`, `d3-cli.md`, `d16.md` (+ 1 ảnh `d03`) → che · đường dẫn mang tên công ty (`notes/d6.md`, 4 ảnh terminal) → che ·
P2-1 ruleset `strict` làm PR deploy "xanh sẵn" cũ đi → checklist: merge hết trước, kiểm `mergeStateStatus` · P2-2 plan trỏ
"quyết định E" → B · P2-3 ghi "lệch guide có chủ ý" (M5, M8 không live) · P2-4 `evidence/README.md` M9 8 → 9 check ·
P2-5 `cost-report.md` chốt một số $16, bỏ câu "bật lại `make down` sau D20" · P3 known-issues #2 đồng bộ với #35.
Chờ CI: P2-6 cổng Semgrep mới chỉ thử bằng JSON chạy ở máy — PR của nhánh này là phép thử thật.

**Vòng 3 — review sub-agent Sonnet 02/10 (kiểm lại vòng 2 + ảnh còn lại + CI PR #90).** Sửa: P1 kịch bản M9 dùng
`demo-leak.env` — bị `.gitignore` `*.env` chặn ở `git add` → đổi `.txt`, thử gitleaks bắt được. Xác nhận: cổng Semgrep mới
**xanh trên CI thật** (PR #90, job `sast + iac`); không còn IP nhà/công ty, email, đường dẫn công ty trong file chữ; ảnh d10,
d11/07–08, d14, d19 m7, d20, d21, d22, d03 sạch. Giữ, không sửa: subscription id trong ảnh d03/d10 và `evidence/d01`, `d08`
(không phải credential — cùng quyết định P3-1); thanh bookmark cá nhân trong 2 ảnh d07 (không có dữ liệu công ty).

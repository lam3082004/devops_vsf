# devops_vsf

Repo thực tập: deploy app lên Azure App Service, CI/CD trunk-based, hạ tầng bằng Terraform, monitoring tập trung.
Đề bài gốc và mọi yêu cầu: [`topic.md`](topic.md).

> README này hiện chỉ chú thích **repo có những gì**. Tới D25 nó phải trở thành hướng dẫn
> để người thứ ba dựng lại hệ thống từ đầu (prereq · các bước · biến cần set · teardown) — deliverable #2 trong `topic.md`.

## Thư mục hiện có

| Đường dẫn | Là gì |
|---|---|
| `topic.md` | Đề bài (thay `a.md` cũ). Authority cho mọi yêu cầu M1–M11, S1–S3, deliverables, lịch 25 ngày, kèm mục bổ sung Sprint 1–3. |
| `CLAUDE.md` | Luật làm việc của repo (AI-OFF tuần 1, không push `main`, tốn tiền phải hỏi, autoscale ≤ 2 instance…). |
| `docs/plans/active/` | Plan đang chạy — checklist tổng, quyết định, câu hỏi mở cho mentor. Đọc trước khi làm, cập nhật cùng lượt với thay đổi. |
| `docs/guides/` | Hướng dẫn **từng bài** D1→D25 (mục lục ở [`docs/guides/README.md`](docs/guides/README.md)): mô tả bước, cấu hình cần đạt, cách kiểm chứng, bẫy. Cố ý **không chứa code** Terraform/`az`/Dockerfile/YAML. |
| `notes/` | Nhật ký làm thật của từng bài (`d1.md`, `d2.md`, …): mình đã bấm gì, gặp lỗi gì, kết luận gì. Khác `docs/guides/` ở chỗ guides là "phải làm gì", notes là "đã xảy ra gì". |
| `evidence/screenshots/` | Ảnh bằng chứng, mỗi bài một thư mục `dXX/`, bản chốt nộp để ở `mXX/`. Quy ước đặt tên và luật che secret: [`evidence/screenshots/README.md`](evidence/screenshots/README.md). |

## Thư mục sẽ thêm (theo lịch)

| Đường dẫn | Là gì | Bài |
|---|---|---|
| `app/be/` | Backend .NET + Dockerfile. Các endpoint bắt buộc: `/health` `/version` `/load` `/items` `/boom`, log JSON. Test ở `app/be.Tests/`. | D4–D5 |
| `app/fe/` | Frontend Next.js (OpsBoard). Mới khởi tạo, chưa có màn hình. | — |
| `docs/docs_app/` | Tài liệu ứng dụng: brief, PRD, wire-frame, API spec, architecture, database schema. | — |
| `.github/workflows/` | `ci.yml` (gitleaks, `terraform fmt/validate`, test, docker build) và `cd.yml` tách riêng. | D6, D14, D16 |
| `infra/` | Terraform: remote state + locking, App Service, MySQL, ACR, Key Vault, autoscale, alert. | D7–D10 |
| `evidence/M1.md` … `M11.md` | Mỗi must-have một file bằng chứng (log · screenshot · output lệnh). | rải rác |
| `architecture.md` | Sơ đồ mermaid, tách rõ luồng traffic và luồng auth. | cuối |
| `cost-report.md` · `runbook.md` · `known-issues.md` | Deliverable 5, 6, 9. | D20, D22, D24 |
| `ai-failure-log.md` | 6–8 case AI sinh ra thứ sai. | rải rác, ghi ngay khi gặp |
| `review-<tên bạn kia>.md` × 2 | Cross-review tuần 2 và tuần 4. | D15, D23 |

## Luật nhanh

- `main` là nhánh duy nhất sống lâu. Làm việc trên `feat/` · `fix/` · `chore/` → PR → squash merge. Nhánh sống ≤ 2 ngày.
- Mọi PR có mục `## AI usage` ghi rõ phần nào AI viết.
- Thao tác tốn tiền (`terraform apply/destroy`, `az ... create`, test tải, swap slot) phải xác nhận trước.
- Cuối phiên: tắt môi trường Azure, đừng để chạy qua đêm.

Chi tiết đầy đủ: [`CLAUDE.md`](CLAUDE.md).

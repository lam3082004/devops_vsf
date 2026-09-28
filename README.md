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
| `docs/docs_app/` | Tài liệu ứng dụng OpsBoard: brief, PRD, wire-frame, API spec, architecture, database schema, chạy local. |
| `notes/` | Nhật ký làm thật của từng bài (`d1.md`, `d2.md`, …): mình đã bấm gì, gặp lỗi gì, kết luận gì. Khác `docs/guides/` ở chỗ guides là "phải làm gì", notes là "đã xảy ra gì". |
| `app/be/` · `app/be.Tests/` | Backend .NET 10 (OpsBoard) + Dockerfile + test xUnit. Endpoint bắt buộc `/health` `/version` `/load` `/items` `/boom`, log JSON một dòng, tracing OpenTelemetry → App Insights (D20). |
| `app/fe/` | Frontend Next.js (kanban, danh sách, chi tiết, thống kê) + Dockerfile, gọi `be` phía server. |
| `infra/` | Terraform: `bootstrap/` (state storage, identity cho CI/CD) và `app/` (App Service + slot, MySQL, ACR, Key Vault, autoscale, Log Analytics + App Insights). |
| `.github/workflows/` | `ci.yml` (gitleaks, terraform fmt/validate/plan, test, lint, docker build + Trivy), `cd.yml` (build → slot staging → swap), `m6-check.yml`. |
| `scripts/` | Script đo/kiểm: `m2-poll.sh` (M2), `load.sh` + `d19-watch.sh` (M7), `d12-verify.sh`, `install-hooks.sh`. |
| `evidence/` | `M1.md` … `M10.md`, `tracing.md`: bằng chứng từng must-have; `dXX/screenshots/`: ảnh theo bài; `raw/`: log/JSON thô. Quy ước đặt tên và luật che: [`evidence/screenshots-convention.md`](evidence/screenshots-convention.md). |
| `cost-report.md` · `known-issues.md` · `ai-failure-log.md` | Deliverable: chi phí (D20), việc chưa xong / biết là sai, các case AI sinh sai. |
| `Makefile` · `docker-compose.yml` | `make up`/`make down` (Terraform), `make test`/`lint`/`fe-*`, MySQL local. |

## Thư mục sẽ thêm (theo lịch)

| Đường dẫn | Là gì | Bài |
|---|---|---|
| `evidence/M11.md` | Bằng chứng monitoring + alert (dashboard không dùng App Insights). | D21–D22 |
| `architecture.md` | Sơ đồ mermaid ở gốc repo, tách rõ luồng traffic và luồng auth (hiện có bản ở `docs/docs_app/architecture.md`). | cuối |
| `runbook.md` | Runbook alert + incident drill. | D22, D24 |
| `review-<tên bạn kia>.md` × 2 | Cross-review tuần 2 và tuần 4. | D15, D23 |

## Luật nhanh

- `main` là nhánh duy nhất sống lâu. Làm việc trên `feat/` · `fix/` · `chore/` → PR → squash merge. Nhánh sống ≤ 2 ngày.
- Mọi PR có mục `## AI usage` ghi rõ phần nào AI viết.
- Thao tác tốn tiền (`terraform apply/destroy`, `az ... create`, test tải, swap slot) phải xác nhận trước.
- Cuối phiên: tắt môi trường Azure, đừng để chạy qua đêm.

Chi tiết đầy đủ: [`CLAUDE.md`](CLAUDE.md).

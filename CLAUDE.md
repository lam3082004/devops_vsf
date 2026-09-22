# devops_vsf — Azure App Service internship

Đề bài gốc: `topic.md` (authority cho mọi yêu cầu M1–M11, S1–S3, deliverables, lịch).
Plan đang chạy: `docs/plans/active/azure-app-service-internship.md` — đọc trước khi làm, cập nhật cùng lượt với thay đổi.
Hướng dẫn từng bài: `docs/guides/` (mục lục `docs/guides/README.md`). Nhật ký từng bài: `notes/dXX.md`.

## Luật riêng của project (override harness khi xung đột)

- **AI-OFF tuần 1 (D1–D5):** Claude chỉ giải thích khái niệm, đọc docs, review ý hiểu.
  **Không sinh Terraform, lệnh `az`, Dockerfile hay pipeline YAML.** Từ D7 mới được sinh,
  và mỗi PR phải có mục `## AI usage` ghi rõ phần nào AI viết.
- **Không push `main`.** Mọi thay đổi đi qua `feat/` · `fix/` · `chore/` → PR → squash merge. Nhánh sống ≤ 2 ngày.
- **Tốn tiền = hỏi trước:** `terraform apply`, `terraform destroy`, `az ... create`, test tải,
  swap slot trên Azure thật đều cần người dùng xác nhận trong phiên. `terraform plan` thì không.
- **Không để gì chạy qua đêm:** cuối phiên nhắc `make down` nếu môi trường đang bật.
- **Secret:** không đưa secret vào code, app settings plaintext, log hay commit. Secret sống trong Key Vault; state Terraform chứa secret nên storage state phải khoá quyền.
- **Autoscale tối đa 2 instance.** Không đề xuất giá trị lớn hơn.
- **Không dữ liệu công ty:** không đưa config, log, code, dữ liệu từ môi trường VinAI thật vào repo này.
- Mỗi ai-sinh-sai phát hiện được → ghi vào `ai-failure-log.md` (cần 6–8 case).

## Validation

Code: `app/be` (.NET, `make test` · `make lint`) và `app/fe` (Next.js, `make fe-lint` · `make fe-build`).
Contract chính là những gì
`.github/workflows/ci.yml` chạy; cập nhật mục này và `~/.claude/harness/STACKS.md` theo đó.

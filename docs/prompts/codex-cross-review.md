# Prompt Codex — review chéo chỉ đọc (05/10)

Repo `devops_vsf`, nhánh `chore/d25-close-gaps`, thay đổi chưa commit (`git status`, `git diff`). Đọc `CLAUDE.md` và `topic.md` trước.

## Luật cứng
CHỈ ĐỌC. Cấm sửa/tạo/xoá file, `git add|commit|push|stash|checkout`, `terraform apply|destroy|init`, `make up|down`, mọi `az ... create|delete|update|set`, `gh pr|issue create|merge|close`.
Được: `ls`, `cat`, `grep`, `git status|diff|log|show`, `gh ... view|list|api` (GET), `az ... show|list`.
Ghi kết quả CHỈ vào stdout. Không secret/email/IP thật trong báo cáo.

## Việc
1. Với `evidence/S1.md`, `S2.md`, `S3.md`, mục cuối `evidence/M8.md`, đoạn ảnh trong `evidence/M9.md`, bảng Stretch `evidence/README.md`, mục "Đối chiếu topic.md — 05/10" trong plan: kiểm từng khẳng định với repo (file, dòng workflow, PR, số liệu). Liệt kê cái sai hoặc không kiểm được.
2. Tự đối chiếu độc lập `topic.md` mục 4 (M1–M11), 5 (S1–S3), 6 (deliverables 1–10): mục nào tài liệu nói ĐẠT mà bằng chứng không đủ?
3. Tìm mâu thuẫn giữa `README.md`, `known-issues.md`, `evidence/README.md`, plan (số lượng, trạng thái, link gãy trong các file thay đổi hôm nay).

## Báo cáo (tiếng Việt, ≤ 40 dòng)
Mỗi phát hiện: mức P0–P3 · `file:dòng` · bằng chứng (lệnh + output ngắn) · đề xuất. Cuối: danh sách đã kiểm đúng, danh sách không kiểm được.

# AI failure log

Ghi lại các lần AI sinh ra thứ sai, cách phát hiện và cách sửa. Yêu cầu đề bài: 6–8 case.

| # | Ngày | Công cụ | Yêu cầu | AI sinh ra gì | Sai ở đâu | Phát hiện bằng | Cách sửa | Bài học |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-16 | Claude Code | Đếm số outbound IP của Web App bằng `az --query` | `--query "length(split(outboundIpAddresses,','))"` | **JMESPath không có hàm `split()`** — AI nhầm với ngôn ngữ khác | CLI báo `Invalid jmespath query supplied for --query: Unknown function: split()` | Đếm bằng shell: `... -o tsv \| tr ',' '\n' \| wc -l` | AI tự tin với cú pháp query của dịch vụ; luôn chạy thử trước khi đưa vào script/CI |
| 2 | 2026-09-16 | Claude Code | Kiểm chứng access restriction cho cả SCM | Chỉ hướng dẫn `--default-action Deny --scm-default-action Deny` | Thiếu `--use-same-restrictions-for-scm-site true` → SCM thành deny-all, chặn luôn chính mình | `curl` vào `*.scm.azurewebsites.net` trả 403 | Thêm cờ dùng chung luật với main site | Portal có mặc định an toàn ngầm; CLI không — phải kiểm chứng từng bề mặt (main + SCM + từng slot) |
| 3 | 2026-09-17 | Claude Code | Viết CI v1 có job quét secret | Dùng `gitleaks/gitleaks-action@v2` với `permissions: contents: read` | Action cần `pull-requests: write` để bình luận vào PR → `RequestError [HttpError]: Resource not accessible by integration`, job đỏ dù repo sạch | CI đỏ ở PR #1, đọc log job mới thấy | Bỏ action, cài binary gitleaks ghim version 8.30.1 rồi chạy `gitleaks detect --exit-code 1` — giữ token ở mức chỉ đọc | Action của bên thứ ba có thể đòi quyền rộng hơn việc cần làm; chạy CLI trực tiếp vừa ít quyền vừa dễ ghim version |

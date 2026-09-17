# AI failure log

Ghi lại các lần AI sinh ra thứ sai, cách phát hiện và cách sửa. Yêu cầu đề bài: 6–8 case.

| # | Ngày | Công cụ | Yêu cầu | AI sinh ra gì | Sai ở đâu | Phát hiện bằng | Cách sửa | Bài học |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-16 | Claude Code | Đếm số outbound IP của Web App bằng `az --query` | `--query "length(split(outboundIpAddresses,','))"` | **JMESPath không có hàm `split()`** — AI nhầm với ngôn ngữ khác | CLI báo `Invalid jmespath query supplied for --query: Unknown function: split()` | Đếm bằng shell: `... -o tsv \| tr ',' '\n' \| wc -l` | AI tự tin với cú pháp query của dịch vụ; luôn chạy thử trước khi đưa vào script/CI |
| 2 | 2026-09-16 | Claude Code | Kiểm chứng access restriction cho cả SCM | Chỉ hướng dẫn `--default-action Deny --scm-default-action Deny` | Thiếu `--use-same-restrictions-for-scm-site true` → SCM thành deny-all, chặn luôn chính mình | `curl` vào `*.scm.azurewebsites.net` trả 403 | Thêm cờ dùng chung luật với main site | Portal có mặc định an toàn ngầm; CLI không — phải kiểm chứng từng bề mặt (main + SCM + từng slot) |

# Evidence

Hai loại tài liệu, đừng lẫn:

| Thư mục / file | Dùng cho | Ai đọc |
|---|---|---|
| `dXX/` | Bằng chứng học theo từng **bài** (D1–D25): ảnh, log, output lệnh | bạn + mentor khi review tiến độ |
| `M1.md` … `M11.md` | Bằng chứng nộp cho từng **must-have** của đề bài | người chấm |

File `MXX.md` trỏ ngược tới ảnh/log trong `dXX/`, không copy trùng.

## Theo bài

| Bài | Nội dung | Bằng chứng chính |
|---|---|---|
| [d01](d01/) | Azure 101 · RBAC · chi phí | (ảnh bị mất do cache phiên chat bị xoá — dữ liệu đã ghi thành chữ trong `notes/d1.md`) |
| [d02](d02/) | Deploy tay bằng Portal | 28 ảnh: slot bị chặn ở Basic, 403 từ LTE, swap, outbound IP |
| [d03](d03/) | Làm lại bằng Azure CLI | 3 ảnh + output lệnh trong `notes/d3-cli.md` |
| [d04](d04/) | Viết app (Rust — sau đổi C#/.NET, xem `notes/lang-migration-dotnet.md`) | log 7 kịch bản, kết quả test |
| [d05](d05/) | Docker · Trivy · chi phí | bảng so sánh image, output Trivy, ảnh Cost Analysis |
| [d06](d06/) | Repo, ruleset, gitleaks, CI v1 | log push-to-main bị chặn, secret giả bị bắt, merge bị khoá |
| [d07](d07/) | Terraform bootstrap, remote state, OIDC | log state lock, OIDC login/reject |
| [d08](d08/) | Terraform compute + DB (App Service, MySQL) | log apply 2 pha, plan No changes, destroy |
| [d09](d09/) | Terraform ACR + Key Vault + CI plan | log 429 throttle 7 lần, chẩn đoán đa vùng, apply thành công, destroy |
| [d10](d10/) | GATE: destroy → apply lại từ rỗng | cặp log apply/destroy + verify, ảnh Portal → `M8.md` |
| [d11](d11/) | Container pull ACR bằng Managed Identity | 9 ảnh (ACR admin disabled, IAM AcrPull, Deployment Center, env vars 2 slot) → `M1.md` |
| [d12](d12/) | Key Vault reference · MySQL · gỡ quyền → app gãy | **chưa đo** — khung ở `M3.md`, `M4.md`, `M5.md` |

## Must-have (điền dần)

| Mã | Yêu cầu | Trạng thái |
|---|---|---|
| M1 | Deploy bằng Docker image, ACR admin disabled, pull bằng MI | `M1.md` — đạt ở D11; còn ô chứng minh ngược (gỡ AcrPull) hoãn sang D12 |
| M2 | Zero downtime khi deploy | chờ D18 |
| M3 | MySQL + firewall theo outbound IP | `M3.md` khung sẵn, **chưa đo** (D12) |
| M4 | Managed Identity, không secret plaintext | `M4.md` khung sẵn, **chưa đo** (D12) |
| M5 | Key Vault + chứng minh ngược | `M5.md` khung sẵn, **chưa đo** (D12) |
| M6 | IP whitelist 200/403 | chờ D13 (bản làm tay đã có ở d02) |
| M7 | Chiến lược tiết kiệm chi phí | chờ D19–D20 |
| M8 | Terraform toàn bộ hạ tầng | `M8.md` — đạt ở D10 |
| M9 | CI chặn được cái sai | chờ D14 (Trivy baseline đã có ở d05) |
| M10 | CD deploy từ main | chờ D16 |
| M11 | Monitoring | chờ D21–D22 |

Quy ước đặt tên ảnh: xem `screenshots-convention.md`.

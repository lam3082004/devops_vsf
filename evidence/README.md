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
| [d12](d12/) | Key Vault reference · MySQL · gỡ quyền → app gãy | log thô trong `raw/d12-*` (apply, verify, M5 gỡ/trả role, JSON tham chiếu hỏng, AcrPull bị từ chối, plan No changes, destroy) |
| d13–d18 | IP whitelist · CI mở rộng · CD · swap an toàn · zero-downtime | log thô `raw/d13-*`, `raw/d14-*`, `raw/m2-*`; run link CI/CD trong `M9.md`, `M10.md` → `M6.md`, `M9.md`, `M10.md`, `M2.md` |
| [d19](d19/) | Autoscale + right sizing | 3 ảnh Portal (Run history 1→2→1, CPU, M6 site chính) + `raw/d19-*` → `M7.md` |
| [d20](d20/) | Cost report · App Insights · tracing | 2 ảnh Cost analysis, 1 ảnh Failures + `raw/d20-*` → `M7.md` mục 7, `tracing.md` |
| [d21](d21/) | Log Analytics · KQL · Workbook · tracing `fe` | 4 ảnh Workbook (hàng 1–3) + `raw/d21-*` (KQL Q1–Q8, slow log, trace fe→be, giá) → `M11.md`, `docs/logging.md` |
| [d22](d22/) | 3 alert · trigger thật · runbook | 3 ảnh Workbook (health + alert Fired/Resolved, log + trace lúc drill) + `raw/d22-*` (boom, trạng thái alert) → `M11.md` |
| d23 | Agent giới hạn quyền `id-agent-triage` | `agent.md` + `raw/d23-agent-*` (triage, prove 9/9) |
| d24 | 2 drill · README từ clone mới · 4 ảnh email alert | `raw/d24-*` (watch TSV, traffic, actions log, agent triage, fresh-clone log) → `../docs/drills/`, `M8.md` mục Lần cuối |

## Must-have (điền dần)

| Mã | Yêu cầu | Trạng thái |
|---|---|---|
| M1 | Deploy bằng Docker image, ACR admin disabled, pull bằng MI | **`M1.md` — ĐẠT**, gồm cả chứng minh ngược (gỡ AcrPull → `ACRTokenRetrievalFailure`, D12) |
| M2 | Zero downtime khi deploy | **`M2.md` — chờ mentor** (4 lần swap, 0 response non-200 theo chữ đề bài; **10 timeout client** ở 2 lần đo đầu, 6 quanh swap — #21 chưa quy được) |
| M3 | MySQL + firewall theo outbound IP | **`M3.md` — ĐẠT** (31 rule = 31 outbound IP); thiếu ảnh Log stream |
| M4 | Managed Identity, không secret plaintext | **`M4.md` — ĐẠT**; thiếu ảnh Portal và API configreferences cho slot |
| M5 | Key Vault + chứng minh ngược | **`M5.md` — ĐẠT** (`AccessToKeyVaultDenied`, container exit 1 sau 0.2s, hồi phục, plan No changes) |
| M6 | IP whitelist 200/403 | **`M6.md` — ĐẠT** (D13; đo lại 8 bề mặt be+fe ở D16); thiếu 2 ảnh Portal (plan "Còn nợ") |
| M7 | Chiến lược tiết kiệm chi phí | **`M7.md` — ĐẠT**: autoscale + right sizing (D19), cost report [`../cost-report.md`](../cost-report.md) (D20) |
| M8 | Terraform toàn bộ hạ tầng | `M8.md` — **ĐẠT MỘT PHẦN**: đạt ở D10 (destroy → apply từ rỗng); lần 2 trên hạ tầng hiện tại: **hoãn tới sau demo**; D24: clone mới theo README → plan/apply 0 thay đổi, **không destroy** (giới hạn ghi trong file) |
| M9 | CI chặn được cái sai | **`M9.md` — ĐẠT** (cổng Trivy có 1 ngoại lệ hết hạn 15/10, #31; ảnh merge bị khoá: `d25/screenshots/`, 05/10) (D14: 8 required check lúc đó — nay **9** sau job `sast + iac` 01/10; 6 PR cố tình sai đều đỏ đúng job) |
| M10 | CD deploy từ main | **`M10.md` — ĐẠT** (D16; swap an toàn D17) |
| M11 | Monitoring | **`M11.md` — ĐẠT** (D20–D22: Workbook 5 mảng, KQL, tracing be + fe, 3 alert, drill Fired → Resolved, runbook đi thử; **email tới thật 01/10**, 4 ảnh `d24/screenshots/alert-email-*`) — [`tracing.md`](tracing.md), `docs/logging.md`, `runbook.md` |

## Stretch

| Mã | Yêu cầu | Trạng thái |
|---|---|---|
| S1 | Trivy fail khi có CVE critical | **[`S1.md`](S1.md) — ĐẠT** (cổng `CRITICAL,HIGH`; PR #38 đỏ thật); có 1 ngoại lệ hết hạn 15/10 (#31) |
| S2 | MI → MySQL bằng Entra | **[`S2.md`](S2.md) — Không đạt, đóng có chủ đích** (blocker: không có directory role, `allowedToCreateApps=false`) |
| S3 | Private Endpoint thay IP whitelist | **[`S3.md`](S3.md) — Không đạt, bỏ có chủ đích** (lý do trong file) |

Quy ước đặt tên ảnh: xem `screenshots-convention.md`.

| Khác | Yêu cầu | Trạng thái |
|---|---|---|
| Agent | Agent giới hạn quyền (`topic.md`) | **`agent.md` — ĐẠT** (D23: 9/9 phép bị cấm bị chặn đúng loại lỗi) |

## Advanced — AKS (ngoài phạm vi `topic.md`)

Phần **làm thêm** từ 2026-10-12, không thay cho bằng chứng nào ở trên: cùng app chạy trên AKS, mỗi must-have làm lại
bằng cơ chế của Kubernetes. Mục lục và trạng thái: [`advanced/README.md`](advanced/README.md) · log thô `raw/aks-*`.

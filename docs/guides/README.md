# Hướng dẫn từng bài — D1 → D25

Mỗi file là **một bài**, không phải một ngày. Tiến độ tuỳ bạn; thứ tự bài thì **phải giữ** vì bài sau dùng kết quả bài trước.

Nguồn yêu cầu: `topic.md`. Checklist tổng: `docs/plans/active/azure-app-service-internship.md`. Nhật ký từng bài: `notes/dXX.md`. Sổ khái niệm: https://claude.ai/artifact/DcVdzVVpzjVecMt128tGFM

Tài liệu ứng dụng OpsBoard (brief, PRD, wire-frame, API spec, schema, kiến trúc, local dev): `docs/docs_app/README.md`.

## Luật dùng AI khi làm nhanh hơn lịch

Đề bài gắn AI-OFF với **tuần 1 theo lịch** (D1–D5 ≈ 15/09–21/09) và cho bật AI từ **D7 ≈ 23/09**.
Nếu bạn làm tới bài D7–D9 trước 23/09:

- **Tự viết tay** Terraform/CLI/YAML theo hướng dẫn và docs → được.
- **Nhờ AI sinh code** cho các bài đó → chỉ sau 23/09, hoặc khi mentor đồng ý mở sớm (câu hỏi Q8 trong plan).
- Hỏi AI khái niệm, nhờ AI đọc lỗi và giải thích → luôn được.

Vì vậy các file hướng dẫn **không chứa code Terraform, lệnh `az`, Dockerfile hay YAML** — chỉ mô tả bước, cấu hình cần đạt, cách kiểm chứng, bẫy. Phần code bạn tự viết (hoặc làm cùng AI khi đã được phép, khai báo trong PR).

## Danh sách bài

| Bài | Nội dung | Cần xong trước | Tốn tiền Azure | Bằng chứng |
|---|---|---|---|---|
| [D1](../../notes/d1.md) | Azure 101 · RBAC · chi phí | — | Không | ✅ xong |
| [D2](d02-portal-manual.md) | Deploy tay bằng Portal | D1 | có (~$0.12/giờ khi bật) | notes |
| [D3](d03-cli.md) | Làm lại bằng Azure CLI | D2 | có (theo giờ khi bật) | notes |
| [D4](d04-app.md) | Viết app | — | Không | notes |
| [D5](d05-docker-cost.md) | Docker local · Trivy · Cost Analysis | D4, D2–D3 (để có số chi phí) | Không | notes |
| [D6](d06-repo-ci-v1.md) | GitHub repo · ruleset · gitleaks · CI v1 | Q2 | Không | M9 (một phần) |
| [D7](d07-terraform-bootstrap-oidc.md) | Terraform nền · remote state · OIDC | D6 | ~$0 | M8 (một phần) |
| [D8](d08-terraform-compute-db.md) | Terraform: App Service + MySQL | D7 | có (theo giờ khi bật) | — |
| [D9](d09-terraform-acr-kv-make.md) | Terraform: ACR · Key Vault · Makefile · plan trong CI | D8 | có (theo giờ khi bật) | — |
| [D10](d10-gate.md) | **GATE**: destroy → apply | D9 | có (theo giờ khi bật) | **M8** |
| [D11](d11-container-mi.md) | Container pull bằng Managed Identity | D10, D5 | có | **M1** |
| [D12](d12-keyvault-mysql.md) | Key Vault reference · MySQL · gãy khi mất quyền | D11 | có | **M3 M4 M5** |
| [D13](d13-ip-whitelist.md) | IP whitelist | D12 | có | **M6** |
| [D14](d14-ci-extended.md) | CI đầy đủ + bằng chứng đỏ | D6, D5 | Không | **M9** |
| [D15](d15-cross-review-1.md) | Cross-review lần 1 | bạn kia có repo | Không | review × 1 |
| [D16](d16-cd.md) | CD pipeline | D13, D14 | có | **M10** |
| [D17](d17-safe-swap.md) | Swap an toàn | D16 | có | — |
| [D18](d18-zero-downtime.md) | Bằng chứng zero-downtime | D17 | có | **M2** |
| [D19](d19-autoscale.md) | Autoscale · right sizing | D16 | có | M7 (một phần) |
| [D20](d20-cost-report-appinsights.md) | Cost report · App Insights | D19, ≥ 2 ngày dữ liệu chi phí | có | **M7** |
| [D21](d21-logging.md) | Log Analytics · KQL · Workbook | D16 | có | M11 (một phần) |
| [D22](d22-alerts-runbook.md) | 3 alert · trigger thật · runbook | D21 | có | **M11** |
| [D23](d23-limited-agent-review-2.md) | Agent giới hạn quyền · cross-review 2 | D22 | ít | review × 2 |
| [D24](d24-drill-finalize.md) | Incident drill · hoàn thiện tài liệu | D22 | có | M8 cập nhật |
| [D25](d25-demo.md) | Demo 45 phút | tất cả | có | demo |

## Tiến độ

Không ấn định thời lượng hay ngày cho từng bài — làm xong bài nào đánh dấu bài đó trong `notes/dXX.md` và plan. Chỉ giữ thứ tự bài (cột "Cần xong trước") và các mốc mentor cố định: GATE (D10), cross-review lần 1 và 2, demo, và **hạn credit Free Trial 15/10/2026**.

## Thói quen mỗi bài

1. Mở `notes/dXX.md`, ghi giờ bắt đầu.
2. Làm theo guide; chụp bằng chứng đúng lúc (đặc biệt lúc **đỏ**).
3. Mọi thay đổi repo (từ D6): nhánh `feat/…` → PR → CI xanh → squash merge.
4. Tạo resource Azure → cuối buổi `make down` (hoặc xoá RG ở D2–D3). Kiểm tra **Resources** trống.
5. Ghi lại lỗi AI sinh sai vào `ai-failure-log.md`.

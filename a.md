# Đề bài thực tập — Deploy, vận hành app trên Azure App Service và triển khai hệ thống monitoring tập trung

5 tuần · 2 intern làm độc lập, đề bài giống nhau

---

## 1. Đề bài

Viết một app web nhỏ, đóng gói Docker, deploy lên Azure App Service, dựng pipeline CI/CD theo trunk-based, và xây monitoring cho nó. Toàn bộ hạ tầng quản lý bằng Terraform.

**App làm gì không quan trọng, tự nghĩ ứng dụng của app**

---

## 2. App bắt buộc có các endpoint sau

Chọn endpoint để mỗi yêu cầu hạ tầng đều chứng minh được.

| Endpoint | Dùng để chứng minh |
|---|---|
| `GET /health` | Warm-up slot, probe |
| `GET /version` → trả build SHA | Zero-downtime |
| `GET /load?seconds=n` đốt CPU | Autoscale |
| `GET\|POST /items` CRUD 1 bảng | MySQL + Managed Identity |
| `GET /boom` ném exception | Alert + App Insights |
| Log dạng JSON có cấu trúc | Log Analytics + KQL |

---

## 3. Quy tắc nhánh — trunk-based

- `main` là nhánh duy nhất tồn tại lâu dài. Không có `develop`, không có `release`.
- Feature branch sống **tối đa 2 ngày**. Đặt tên `feat/`, `fix/`, `chore/`.
- Squash merge. Cấm force push vào `main`.
- `main` luôn ở trạng thái deploy được.
- **Chỉ `main` mới được deploy lên App Service.**

Branch policy bắt buộc đặt trên `main`: yêu cầu PR · yêu cầu Build Validation xanh.
Sử dụng github để làm source control
---

## 4. Must-have 

| # | Yêu cầu | Cách chứng minh |
|---|---|---|
| M1 | Deploy bằng Docker image | ACR admin user **disabled**; App Service pull image bằng managed identity |
| M2 | Zero downtime khi deploy | Script poll `/version` 1 lần/giây trong lúc swap. Nộp log thô: 0 response non-200, version đổi A→B |
| M3 | MySQL làm database | `/items` đọc ghi được. Firewall MySQL chỉ mở cho outbound IP của App Service |
| M4 | Managed Identity truy cập managed service | MI đọc Key Vault + pull ACR. Không secret plaintext nào trong app settings |
| M5 | Key Vault lưu secret | App config dùng `@Microsoft.KeyVault(...)`. Chứng minh ngược: **xoá quyền MI khỏi KV → app phải gãy** |
| M6 | Chỉ access bằng IP whitelist | `curl` từ IP cho phép → 200; từ IP khác (hotspot điện thoại hoặc VM region khác) → 403 |
| M7 | Chiến lược tiết kiệm chi phí | Báo cáo 1 trang: tier đang dùng và tại sao · autoscale rule (**max 2 instance**) · 3 biện pháp đã áp dụng · chi phí thật từ Cost Analysis |
| M8 | Terraform toàn bộ hạ tầng | `terraform destroy` → `apply` ra môi trường chạy được, **không một thao tác tay**. Nộp log |
| M9 | **CI — gate trước khi merge** | Xem bảng dưới |
| M10 | **CD — deploy từ main** | Merge vào `main` → build → push ACR → deploy staging slot → swap. Nộp 1 lần chạy end-to-end |
| M11 | Monitoring | Xem bảng dưới |

### M9 — CI, chạy trên PR, **không deploy gì cả**

| Bước | Cách chứng minh |
|---|---|
| Secret scan (gitleaks hoặc trufflehog) | Mở 1 PR có cắm secret giả → **pipeline phải đỏ và chặn merge**. Nộp screenshot |
| Lint + unit test | |
| `terraform fmt -check` + `terraform validate` + `terraform plan` | Plan xuất ra artifact để reviewer đọc trong PR |
| Docker build (không push) | Build fail thì PR đỏ |
| Trivy để scan docker image | Phải không còn CVE khi scan Trivy |
| Branch policy Build Validation trên `main` | Thử merge khi pipeline đang đỏ → **phải bị chặn**. Nộp screenshot |

> Chứng minh cốt lõi của M9 không phải "pipeline chạy xanh" mà là **pipeline chặn được cái sai**. Cả hai bằng chứng đều là ảnh chụp lúc nó đỏ.

### M11 — Monitoring

| Mục tiêu | Cách chứng minh |
|---|---|
| App performance | Dashboard (không enable App Insight): response time · request rate · failure rate |
| Infra | Metric App Service (CPU, memory, HTTP queue) + MySQL (CPU, connections, storage) |
| View log | **Nghiên cứu giải pháp cho logging và dashboard view log** |
| Cảnh báo | 3 alert (5xx rate · CPU cao · MySQL connections) + action group gửi email + **trigger thật ít nhất 1 alert** |

---

## 5. Stretch

| # | Nội dung | Ghi chú |
|---|---|---|
| S1 | Trivy scan image trong CI, fail khi có CVE critical | Rẻ nhất — hạ tầng scan đã có sẵn từ M9 |
| S2 | MI → MySQL bằng Entra authentication | Chỉ khả thi trên sub cá nhân — cần Graph permission cấp tenant |
| S3 | Private Endpoint thay IP whitelist | Cần thêm jump VM để demo được |

---

## 6. Deliverables

Nộp cuối D25, tất cả trong **một repo duy nhất**.

| # | File / hạng mục | Yêu cầu |
|---|---|---|
| 1 | Repo | Source app + Dockerfile + Terraform + pipeline YAML (CI và CD tách file) |
| 2 | `README.md` | Người thứ ba đọc và dựng lại được từ đầu: prereq · các bước · biến cần set · cách teardown |
| 3 | `architecture.md` | Sơ đồ mermaid, **tách rõ luồng traffic và luồng auth** |
| 4 | `evidence/M1.md` … `M11.md` | Mỗi must-have một file: log, screenshot hoặc output lệnh |
| 5 | `cost-report.md` | 1 trang, theo M7 |
| 6 | `runbook.md` | Cho alert nghiêm trọng nhất: triệu chứng · xác nhận · xử lý · rollback · escalate |
| 7 | `ai-failure-log.md` | 6–8 case AI sinh ra thứ sai |
| 8 | `review-<tên bạn kia>.md` × 2 | Cross-review tuần 2 và tuần 4 |
| 9 | `known-issues.md` | Cái gì chưa xong · cái gì biết là sai · làm lại thì làm khác chỗ nào |
| 10 | Demo 45 phút | Live, chạy thật, **không slide** |


---

## 7. Lịch 25 ngày

| Tuần | Ngày | Nội dung |
|---|---|---|
| **1** | D1–5 | **AI-OFF cho phần làm.** Azure 101 + RBAC · deploy tay App Service + MySQL bằng Portal rồi bằng CLI · Cost Analysis · viết app + Dockerfile chạy local |
| **2** | D6 | Repo + trunk-based rules + branch policy + **CI v1** (gitleaks + `terraform fmt/validate`) |
| | D7–10 | **AI bật, khai báo trong PR.** Terraform hoá toàn bộ · remote state + locking · `destroy`/`apply`. Mọi PR đi qua CI. **D10 = GATE** |
| **3** | D11–15 | ACR + container deploy · Key Vault + MI · kết nối MySQL · IP whitelist · mở rộng CI (test + docker build) · cross-review lần 1 |
| **4** | D16–18 | **CD pipeline**: build → push ACR → staging slot → swap. Bằng chứng zero-downtime |
| | D19–20 | Autoscale + right sizing + cost report · App Insights |
| **5** | D21–25 | D21 Logging · D22 alert + runbook + trigger thật · D23 bài agent giới hạn quyền + cross-review lần 2 · D24 incident drill + hoàn thiện evidence · D25 demo + tổng kết |

**GATE D10:** không dựng lại được hạ tầng bằng Terraform và không giải thích được state / lock / dependency → dừng hoặc đổi scope. Không kéo dài để cho qua.

---

## 8. Quy tắc làm việc

- Mọi thay đổi qua PR. Không ai push thẳng `main`, kể cả khi làm một mình.
- Cài pre-commit hook gitleaks ở local. **Hook chặn secret vào repo, không chặn được việc dán vào khung chat AI** — chỗ đó chỉ có kỷ luật.
- Tuần 1 AI-OFF cho phần làm — được hỏi khái niệm, cấm sinh Terraform/CLI. Từ D7 bật, khai báo trong PR.
- `make up` sáng, `make down` chiều. **Không để gì chạy qua đêm.**
- Autoscale max 2 instance. Test tải ngắn.
- Kẹt quá 45 phút thì hỏi. Kẹt quá 1 ngày mà không hỏi là lỗi bị trừ điểm.
- Sandbox không chứa dữ liệu thật → dán gì vào AI cũng được. Ngược lại, **không gì từ môi trường công ty đi qua tay intern**.
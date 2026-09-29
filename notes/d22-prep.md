# D22 — Kế hoạch chi tiết: 3 alert · action group · trigger thật · runbook — M11 dòng cảnh báo

Guide gốc: `docs/guides/d22-alerts-runbook.md` · Nhật ký: `notes/d22.md` · Bằng chứng: `evidence/M11.md`
(phần alert) · Deliverable: `runbook.md` · Phiên trước: `notes/d21.md`

> Viết 2026-09-29 cùng phiên với D21 (người dùng yêu cầu làm D21 + D22 liền, tự review, tự sửa).
> Môi trường `jcip0s` **đang bật**.

## Đọc 60 giây này trước

| | |
|---|---|
| **Việc chính** | (1) Terraform: action group `ag-vsf-oncall` (email) + 3 alert: **5xx rate** (log alert) · **CPU cao** (metric, Plan) · **MySQL active connections** (metric) · (2) Trigger thật alert 5xx bằng `/boom` → Fired + email + Resolved · (3) `runbook.md` cho alert 5xx, **đi thử** trong lúc trigger · (4) ô "alert đang bắn" trong Workbook D21 |
| **Không làm** | Test tải CPU (người dùng chỉ duyệt trigger 5xx). Alert thứ 4 |
| **Tốn tiền?** | Giá tra 29/09 (Retail Prices API, Central India): log alert 5 phút **$1,50/tháng/time series**; metric alert **$0,10/tháng/time series**; email action group 1 000 email/tháng đầu miễn phí. Tổng ≈ **$1,70/tháng**. Trigger: ~480 request `/boom` → vài trăm KB log |
| **Ai chạy** | AI: Terraform, script trigger, runbook, bằng chứng. 👤 Người dùng: đã duyệt trước merge + apply + trigger 5xx (29/09); chụp email nếu extension không đọc được hộp thư |
| **Xong khi** (guide) | action group test OK · 3 alert bằng Terraform · ≥ 1 alert Fired thật + email + Resolved · `runbook.md` đã đi thử · `evidence/M11.md` đầy đủ |

## Dữ kiện đã đọc (29/09 — đừng đoán lại)

| Dữ kiện | Nguồn | Hệ quả |
|---|---|---|
| `Microsoft.AlertsManagement` **Registered**, `Microsoft.Insights` Registered | `az provider show` | Bẫy §0 của guide không còn |
| MySQL B1ms `max_connections = 171` (mặc định) | `az mysql flexible-server parameter show` | Ngưỡng 75% ≈ **128** (quyết định C) |
| Metric: Web App `Requests`/`Http5xx` (Total), `HttpResponseTime` (Average), `HealthCheckStatus`; Plan `CpuPercentage`; MySQL `active_connections` (Maximum), `cpu_percent`, `storage_percent` | `az monitor metrics list-definitions` | Tên metric trong Terraform/Workbook |
| Q3 chưa có trả lời mentor → người dùng chốt **rate** (log alert) 29/09 | phiên 29/09 | Alert 5xx = KQL trên `AppServiceHTTPLogs` (D21 Pha A) |
| Email nhận alert: nằm trong `infra/app/terraform.tfvars` (gitignored) như `allowed_ips` | quyết định người dùng 29/09 | CI plan không có tfvars → báo "xoá receiver" giả, cùng loại với `ip_restriction` giả |
| Q5 (sub Free Trial hết hạn 15/10 = D23) chưa trả lời | plan | D22 làm xong **trước** 15/10 — không chặn |
| Log có độ trễ 2–5 phút; log alert đánh giá 5 phút/lần | D21 Pha A | Từ lúc bắt đầu `/boom` tới Fired ≈ 10–15 phút |

## Quyết định (chốt 29/09)

| # | Câu hỏi | Chốt | Lý do |
|---|---|---|---|
| A | 5xx: count hay rate | **rate** — log alert (người dùng chốt) | Khớp chữ "5xx rate" của `topic.md` |
| B | Rate tính trên bề mặt nào, bao nhiêu time series | `be` + `fe` **production**, rate **theo từng app**, lấy **max** → **1 time series** ($1,50/tháng) | Mỗi app một series là $3/tháng; `fe` lỗi thường do `be` lỗi. Staging bỏ — không phục vụ người dùng. Truy ra app nào: kết quả query của alert |
| C | Ngưỡng MySQL connections | **> 128** (75% × 171), Maximum, cửa sổ 5 phút | Guide: 70–80% `max_connections`. App dùng pool MySqlConnector (mặc định tối đa 100/instance) × tối đa 2 instance = 200 > 171 → ngưỡng này bắt được lúc pool phình khi scale |
| D | Ngưỡng 5xx | rate **> 5%** **và** tổng **≥ 20** request trong cửa sổ **10 phút**, đánh giá **5 phút/lần**, Sev **1** | Guide. Cửa sổ 10 phút (không phải 5) vì log trễ 2–5 phút — cửa sổ 5 phút dễ đếm thiếu |
| E | CPU | Plan `CpuPercentage` avg **> 80%** / **15 phút**, tần suất 1 phút, Sev 2 | Guide nói 10 phút nhưng metric alert chỉ nhận PT1M/5M/15M/30M/1H… (validate từ chối PT10M) → 15. Chọn **Plan**, không phải Web App (bẫy guide) |
| F | Auto-mitigate | bật cho cả 3 | Guide: tự đóng khi hết điều kiện → có email Resolved |
| G | Link runbook trong mô tả alert | URL GitHub `runbook.md` trên `main` | Người trực mở được ngay từ email |
| H | Ô "alert đang bắn" trong Workbook | Azure Resource Graph `alertsmanagementresources` lọc RG | Đủ 5 mảng dashboard của plan (metric · log · trace · alert · health) |

## Pha A — Terraform (gộp PR với D21 Workbook + tracing `fe`) · plan không tốn tiền

- [ ] A1. `variables.tf`: `alert_email` (string, default `""`, **không commit giá trị**), mô tả như `allowed_ips`
- [ ] A2. `alerts.tf` (mới): `azurerm_monitor_action_group.oncall` (`ag-vsf-oncall`, short name `vsfoncall`,
      `dynamic "email_receiver"` khi email khác rỗng, `use_common_alert_schema = true`)
- [ ] A3. `azurerm_monitor_scheduled_query_rules_alert_v2.http_5xx_rate` — scope = workspace; query D21 Q2 rút
      gọn; `metric_measure_column = "rate_pct"`, `GreaterThan 5`, `window_duration = PT10M`,
      `evaluation_frequency = PT5M`, `auto_mitigation_enabled = true`, failing periods 1/1
- [ ] A4. `azurerm_monitor_metric_alert.cpu_high` (scope Plan) · `azurerm_monitor_metric_alert.mysql_connections` (scope MySQL)
- [ ] A5. `terraform.tfvars` (local) thêm `alert_email`. `plan` → mong đợi thêm **4 to add** cho phần alert
- [ ] A6. Merge + apply (đã duyệt trước) → Portal/CLI: action group **Test** (`az monitor action-group test-notifications create`) → email thử

## Pha B — Trigger thật 5xx · ⚠️ đã duyệt trước (1 lần)

- [ ] B1. `scripts/boom.sh` (mới, ngắn): gọi `/boom` production `be` 1 lần/giây, **tự dừng** sau `DURATION` (mặc định
      480s), ép `curl -4` (M6), in mã trả về mỗi 30s. Không chạy song song với `m2-poll.sh`
- [ ] B2. Chạy **từ IP whitelist**. Ghi giờ UTC bắt đầu/kết thúc
- [ ] B3. Theo dõi: `az monitor alert` / Resource Graph `alertsmanagementresources` tới **Fired** → email (hỏi người dùng
      xác nhận hộp thư nếu không đọc được) → sau khi dừng ~10–15 phút: **Resolved** + email resolved
- [ ] B4. Truy vết alert → request (checkbox plan D22): kết quả query alert → KQL Q4 lấy `trace_id` của một dòng
      `/boom` → `AppRequests`/`AppExceptions` cùng `OperationId` → log `boom` cùng `trace_id`
- [ ] B5. Ảnh: alert Fired, alert Resolved, Workbook cùng khoảng thời gian (đỉnh 5xx) — Claude in Chrome

## Pha C — `runbook.md` + đi thử

- [ ] Theo khung guide §4, lệnh/truy vấn **chạy được thật** (KQL lưu ở `docs/logging.md`, lệnh `az` swap ngược
      của D17). Đi thử đúng từng bước trong B3–B4, sửa bước nào không làm được — ghi "đã đi thử 29/09"

## Pha D — Ghi chép

- [ ] `evidence/M11.md` phần alert · `notes/d22.md` · plan tick D22 · `known-issues.md` nếu có

## Bảng bẫy

| # | Bẫy | Tránh |
|---|---|---|
| T1 | Log alert đếm thiếu vì log trễ | Cửa sổ 10 phút, tần suất 5 phút |
| T2 | CPU alert gắn nhầm Web App | Scope = Plan |
| T3 | `boom.sh` quên dừng → alert treo, log tăng | Script tự dừng theo `DURATION`, `trap` Ctrl-C |
| T4 | Email vào spam / không tới | Action group Test trước khi trigger |
| T5 | Commit email vào repo | Chỉ `terraform.tfvars` (gitignored); gitleaks + `git diff` trước commit |
| T6 | Tổng request < 20 trong cửa sổ → rate đúng nhưng không bắn | `/boom` 1/giây × 8 phút = ~480 request |
| T7 | Lịch sử alert mất khi `make down` | Chụp/ghi bằng chứng ngay trong ngày |

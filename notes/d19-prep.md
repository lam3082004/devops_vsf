# D19 — Kế hoạch chi tiết: Autoscale + right sizing (M7 phần autoscale)

Guide gốc: `docs/guides/d19-autoscale.md` · Nhật ký: `notes/d19.md` (tạo khi làm) ·
Bằng chứng: `evidence/M7.md` (phần autoscale; phần cost report là D20) · Phiên trước: `notes/d18.md`

> **Điều kiện vào D19 — ĐÃ ĐẠT (2026-09-27):** D18 xong phần việc (`evidence/M2.md`; M2 chờ mentor quyết về 10 timeout — không chặn D19, D19 còn đo lại được M2 lúc 2 instance, quyết định E). Môi trường `jcip0s`
> **đang bật** theo quyết định người dùng. Đã đọc tại chỗ (chỉ đọc, 2026-09-27): plan
> `asp-vsf-dev` = **P0v3, capacity 1**, **chưa có autoscale setting nào** trong `rg-vsf-dev`, provider
> `Microsoft.Insights` = **Registered**. Pha B vẫn phải đọc lại trước khi apply.

## Đọc 60 giây này trước

| | |
|---|---|
| **Tốn tiền?** | Pha A (Terraform + script tải + kiểm khô) **không**. `terraform apply` (Pha B) và test tải (Pha C) **có**: instance thứ 2 của P0v3 ≈ **$0.082/giờ** (Central India), chỉ chạy trong khoảng ~30–40 phút quanh test tải. Mọi bước có ⚠️ phải hỏi người dùng trong phiên. |
| **Làm gì** | (1) Terraform `azurerm_monitor_autoscale_setting` gắn vào **Plan** (min 1 · default 1 · **max 2**, out CPU > 70% trong 5 phút, in CPU < 30% trong 10 phút) · (2) `scripts/load.sh`: N request `/load` song song, **tối đa 8 phút** rồi dừng hẳn · (3) quan sát 1 → 2 → 1 bằng `az` + ảnh Portal · (4) bảng right sizing + kết luận tier. |
| **Ai chạy** | AI viết Terraform/script/docs (được phép từ D7, PR có `## AI usage`). `terraform apply`, chạy `scripts/load.sh` lên production, và merge PR (mỗi merge = một lần CD swap thật) → **hỏi người dùng trước**. Ảnh Portal (Metrics, Run history) → 👤 người dùng chụp, hoặc ghi nợ ảnh vào `notes/screenshot-debt.md`. |
| **Xong khi** | 3 ô của guide: autoscale bằng Terraform, max 2 · bằng chứng 1→2 và 2→1 · bảng right sizing + kết luận tier. |
| **Sau D19** | D20 (cost report + App Insights) dùng bảng right sizing và giá ở đây. |

## Dữ kiện đã đọc từ repo (đừng đoán lại)

| Dữ kiện | Nguồn | Hệ quả cho D19 |
|---|---|---|
| **`be` và `fe` dùng CHUNG một plan** `azurerm_service_plan.app` | `infra/app/app.tf:5`, `infra/app/app-fe.tf:64` | Autoscale theo CPU của plan scale **cả hai app** cùng lúc. Tính tiền theo **instance của plan**, nên `fe` lên 2 instance không tốn thêm. |
| Plan khai `worker_count = 1`, **không** có `lifecycle.ignore_changes` | `infra/app/app.tf:11` | Khi autoscale đang ở 2 instance, `terraform plan` sẽ thấy drift `worker_count 2 → 1`, và `apply` lúc đó sẽ **kéo về 1**, đánh nhau với autoscale → quyết định A |
| `/load?seconds=N` đốt CPU `N` giây trong `Task.Run` (1 request ≈ 1 luồng bận); `LOAD_MAX_SECONDS` mặc định **60**, cho phép 1..300 | `app/be/Services/LoadService.cs`, `app/be/Infrastructure/Config.cs:49` | `seconds > 60` → **400**, CPU không lên (bẫy của guide). P0v3 = 1 vCPU: 2–4 request song song là đủ |
| Health check `be` = `/health`, eviction 5 phút; `always_on = true` | `infra/app/app.tf` (D17) | Lúc CPU bão hoà, `/health` có thể chậm → theo dõi, đừng để test tải biến thành sự cố health check |
| Identity CI chạy `plan` có **Reader** ở scope RG | `infra/app/ci-permissions.tf:14` | Đủ để đọc `Microsoft.Insights/autoscaleSettings` — job `terraform plan` của CI không cần thêm quyền (kiểm lại ở Pha A khi CI chạy) |
| Region **Central India** (không phải Southeast Asia như bảng giá của guide) | `infra/app/variables.tf:1` | Bảng giá của guide lỗi thời — dùng bảng dưới |

Giá Linux pay-as-you-go **Central India**, Azure Retail Prices API, tra 2026-09-27 (tra lại khi viết
cost report D20):

| Tier | vCPU / RAM | $/giờ | Slot | Autoscale | Nhận xét |
|---|---|---|---|---|---|
| B1 | 1 / 1.75 GB | 0.018 | ❌ | ❌ | loại: không slot (M2), không autoscale (M7) |
| S1 | 1 / 1.75 GB | 0.088 | ✅ | ✅ | đắt hơn P0v3, RAM ít hơn |
| **P0v3** | 1 / 4 GB | **0.082** | ✅ | ✅ | **đang dùng** — rẻ nhất có slot + autoscale |
| P0v4 | 1 / 4 GB | 0.102 | ✅ | ✅ | đắt hơn P0v3 ~24% |
| P1v3 | 2 / 8 GB | 0.164 | ✅ | ✅ | chỉ cân nhắc nếu số đo cho thấy RAM/CPU không đủ |

## Quyết định phải chốt TRƯỚC khi viết Terraform

Ghi câu trả lời vào `notes/d19.md` mục Decisions.

| # | Câu hỏi | Lựa chọn | Đề xuất |
|---|---|---|---|
| A | Ai sở hữu số instance: Terraform (`worker_count`) hay autoscale? | (a) giữ `worker_count = 1` + `lifecycle { ignore_changes = [worker_count] }` trên plan · (b) bỏ hẳn `worker_count` · (c) để nguyên | **(a).** Terraform đặt giá trị **ban đầu**, autoscale điều khiển lúc chạy. (c) làm `plan` báo drift mỗi lần đang 2 instance và `apply` vô tình kéo về 1 giữa lúc tải cao. (b) để provider tự chọn mặc định → khó đọc. Thêm comment giải thích ngay tại chỗ. Kiểm: `plan` ra **No changes** cả khi đang 2 instance (Pha C) |
| B | Chấp nhận `fe` scale cùng `be` (chung plan)? | (a) chấp nhận · (b) bật per-site scaling, ghim `fe` 1 instance | **(a).** Guide yêu cầu target là **Plan**, tiền tính theo instance của plan, và `fe` đã có health check + warm-up (D17). (b) thêm cấu hình mới chỉ để tiết kiệm 0 đồng. Ghi rõ trong `evidence/M7.md`: "2 instance" nghĩa là 2 máy, mỗi máy chạy cả `be` lẫn `fe` |
| C | Thông báo email khi scale? | (a) không — lấy bằng chứng từ Run history + Activity Log + `az` · (b) email qua biến trong `terraform.tfvars` | **(a).** Guide ghi "tuỳ chọn". Email là thông tin cá nhân: không đưa vào code, còn đưa vào tfvars thì nó nằm trong state. Activity Log đã ghi sự kiện scale có timestamp, đủ làm bằng chứng và đối chiếu được như D18 |
| D | Hình dạng tải | (a) N=3 luồng, mỗi luồng lặp `/load?seconds=55`, trần cứng **8 phút** · (b) N=2 · (c) N=4 | **(a).** 1 vCPU, 3 luồng bận → CPU ~100% ổn định kể cả khi một request đang được gửi lại. `55 < 60` tránh 400. `curl --max-time 75` (> 55s + độ trễ WARP ~1.6s). Trần 8 phút là tổng, không phải mỗi luồng. Nếu 5 phút đầu CPU < 70% thì tăng lên 4, **không** kéo dài quá 8 phút |
| E | Có chạy `scripts/m2-poll.sh` song song trong lúc tải + scale? | (a) có · (b) không | **(a).** Guide cảnh báo: scale in dừng một instance → có thể ra 5xx. D18 đã có công cụ đo đúng việc này, cột `t_tls`/`t_ttfb` giúp tách nhiễu WARP. Thêm được một lần đo "2 instance" mà `evidence/M2.md` đang ghi là hạn chế. Không tốn thêm tiền |
| F | Bằng chứng 1→2→1 lấy thế nào | (a) `az` ghi log thô (capacity mỗi 30s, Activity Log autoscale, metric CPU PT1M) + 👤 ảnh Portal · (b) chỉ ảnh Portal | **(a).** Ảnh Portal là thứ guide yêu cầu, nhưng log `az` có timestamp đối chiếu được với log tải và log M2 — cùng tinh thần "log thô hơn screenshot" của D18. Ảnh nào chưa chụp thì ghi vào `notes/screenshot-debt.md` |

## Hiểu trước khi làm — 5 điều

1. **Autoscale gắn vào Plan, metric cũng lấy từ Plan.** `target_resource_id` và
   `metric_trigger.metric_resource_id` đều là `azurerm_service_plan.app.id`, metric `CpuPercentage`
   (namespace `microsoft.web/serverfarms`). Lấy metric của Web App (`CpuTime`) là bẫy #1 của guide:
   rule không kích hoạt như mong đợi.
2. **Thời gian phản ứng là vài phút, không phải vài giây.** Scale out cần: CPU trung bình > 70% qua
   **cửa sổ 5 phút** + chu kỳ đánh giá của autoscale (~1 phút) + thời gian cấp instance và kéo
   container (D17: khởi động ~1 phút). Dự kiến thấy instance thứ 2 **6–9 phút** sau khi bắt đầu tải
   — sát trần 8 phút. Nếu chưa thấy thì **không kéo dài tải**, mà đọc Activity Log/metric xem rule
   đã được đánh giá chưa.
3. **Scale in có chống flapping.** Trước khi giảm, autoscale ước tính CPU sau khi giảm: 2 instance ở
   20% → 1 instance ~40%, vẫn < 70% nên được giảm. Nếu ngưỡng in quá gần ngưỡng out (ví dụ 60/70),
   ước tính sau khi giảm sẽ vượt ngưỡng out → autoscale **từ chối** giảm (đó là cơ chế chống
   flapping, không phải lỗi). 70/30 với cửa sổ in 10 phút > out 5 phút là khoảng cách an toàn.
   Dự kiến 2→1 khoảng **10–20 phút** sau khi dừng tải.
4. **`ignore_changes` là hợp đồng giữa Terraform và autoscale** (quyết định A). Kiểm hợp đồng bằng
   `terraform plan` đúng lúc đang 2 instance: phải ra No changes. Không kiểm lúc đó thì không biết nó đúng.
5. **Không để CD swap chồng lên test tải.** Mỗi merge vào `main` là một lần swap thật (D18). Swap
   lúc đang 2 instance + đang tải làm log M2 và log scale lẫn vào nhau, không tách được nguyên nhân.
   Pha C: không merge gì từ lúc bắt đầu tải tới khi đã về 1 instance.

---

## Pha A — Terraform + script (KHÔNG tốn tiền) · ~1.5 giờ

Nhánh: `git fetch && git switch -c feat/d19-autoscale origin/main`

### A1. Terraform `infra/app/autoscale.tf` (file mới) + sửa plan

- [ ] `azurerm_monitor_autoscale_setting.plan`: `target_resource_id = azurerm_service_plan.app.id`,
      `location` cùng RG, `enabled = true`, tags `local.tags`
- [ ] Một `profile`: `capacity { default = 1, minimum = 1, maximum = 2 }` — **maximum 2 là luật
      project, không đề xuất lớn hơn**
- [ ] Rule out: `metric_name = "CpuPercentage"`, `metric_resource_id = azurerm_service_plan.app.id`,
      `time_grain = "PT1M"`, `statistic = "Average"`, `time_window = "PT5M"`,
      `time_aggregation = "Average"`, `operator = "GreaterThan"`, `threshold = 70` →
      `scale_action { direction = "Increase", type = "ChangeCount", value = 1, cooldown = "PT5M" }`
- [ ] Rule in: như trên nhưng `time_window = "PT10M"`, `operator = "LessThan"`, `threshold = 30` →
      `Decrease` 1, `cooldown = "PT10M"`
- [ ] Không có khối `notification` (quyết định C)
- [ ] `infra/app/app.tf`: plan thêm `lifecycle { ignore_changes = [worker_count] }` + comment (quyết định A)
- [ ] Comment Decision tại chỗ: vì sao 70/30, vì sao in 10 phút > out 5 phút (điều 3)
- [ ] `terraform fmt` · `terraform validate` · `terraform plan -lock=false` → mong đợi **1 to add, 0
      to change, 0 to destroy** (`ignore_changes` không sinh diff khi đang 1 instance). Khác đi → dừng, đọc diff

### A2. `scripts/load.sh`

- [ ] Tham số: `--url` (base của `be`, bắt buộc), `--workers` (mặc định 3), `--seconds` (mặc định 55,
      **từ chối > 60** trừ khi truyền `--max-seconds` khớp `LOAD_MAX_SECONDS`), `--duration` (mặc định
      480, **từ chối > 480**)
- [ ] Mỗi worker: vòng lặp `curl -4 -s --max-time 75 "$URL/load?seconds=$S"` tới khi hết `--duration`;
      mỗi request ghi một dòng TSV: `ts_start_utc  worker  http_code  curl_exit  time_total  body_rút_gọn`
- [ ] Hết giờ, hoặc Ctrl+C/SIGTERM → dừng **mọi** worker (kể cả curl đang chờ — khác `m2-poll.sh`: ở
      đây request dở dang **phải** bị huỷ, đó là cả mục đích của nút dừng) → in tóm tắt: số request
      theo mã, giờ bắt đầu/kết thúc UTC
- [ ] Log `evidence/raw/d19-load-<UTC>.log`; không ghi đè file có sẵn
- [ ] Không `set -e` trong worker (bẫy P1 của D18)

### A3. `scripts/d19-watch.sh` (theo dõi, chỉ đọc)

- [ ] Mỗi 30s ghi một dòng: `ts_utc  capacity(plan)  số instance be (az webapp list-instances)
      CPU% phút gần nhất` → `evidence/raw/d19-watch-<UTC>.log`. Dừng bằng Ctrl+C
- [ ] Chỉ `az ... show/list`, không lệnh ghi nào

### A4. Kiểm khô

- [ ] `load.sh` trên server giả cục bộ (dùng lại mẫu `fake.py` của D18, thêm route `/load` ngủ N
      giây): 3 worker × `--duration 20 --seconds 5` → đủ dòng, dừng đúng hạn, Ctrl+C giết được curl
      đang chờ (đếm tiến trình `curl` còn sống sau khi dừng = 0)
- [ ] Truyền `--seconds 61` → script từ chối trước khi gửi request nào; `--duration 600` → từ chối
- [ ] `shellcheck scripts/load.sh scripts/d19-watch.sh`
- [ ] `d19-watch.sh` chạy thật 2 phút (chỉ đọc, không tốn tiền): capacity = 1

### A5. PR → CI → merge

- [ ] PR có `## AI usage`. CI: job `terraform plan` phải thấy **1 to add** (autoscale), không đổi gì khác
- [ ] ⚠️ Merge = một lần CD swap thật (không path filter) — hỏi người dùng. Có thể bật
      `m2-poll.sh` quanh lần merge này để có thêm một lần đo M2 (tuỳ chọn, không bắt buộc cho D19)
- [ ] **Merge KHÔNG apply Terraform** — CD chỉ build/swap. Apply là Pha B

---

## Pha B — Apply (⚠️ TỐN TIỀN rất ít — autoscale setting miễn phí, hỏi trước vì là `terraform apply`)

- [ ] B0. Đọc lại: capacity plan = 1, không autoscale nào, IP thoát 15/15 = whitelist (như D18 B1),
      production `be`/`fe` `/version` 200
- [ ] B1. ⚠️ Xác nhận với người dùng → `terraform -chdir=infra/app apply` từ `main` đã có PR A
      (không apply từ nhánh chưa merge; kiểm `pwd` + `git log -1` trước khi apply — `ai-failure-log.md` #11 từng apply nhầm code vì sai thư mục). Mong đợi `1 added, 0 changed, 0 destroyed`
- [ ] B2. `az monitor autoscale show -g rg-vsf-dev -n <tên>` → lưu JSON vào `evidence/raw/`:
      đúng min/default/max 1/1/2, 2 rule, metric `CpuPercentage` trên **serverfarms**
- [ ] B3. `terraform plan -lock=false` → **No changes**

## Pha C — Test tải + quan sát 1→2→1 (⚠️ TỐN TIỀN — instance thứ 2 ~30–40 phút)

Mở 3 tiến trình, cùng đồng hồ UTC:

- [ ] C0. Không có PR nào sắp merge; `gh run list -w CD -L 1` không `in_progress`
- [ ] C1. Bật `scripts/d19-watch.sh` và `scripts/m2-poll.sh` (quyết định E) → baseline 2 phút
- [ ] C2. ⚠️ Xác nhận với người dùng → `scripts/load.sh --url https://app-vsf-<suffix>.azurewebsites.net`
      (3 worker, 8 phút). Ghi giờ bắt đầu
- [ ] C3. Chờ. Mong đợi: CPU plan > 70% sau ~1–2 phút, instance thứ 2 sau ~6–9 phút (điều 2).
      Trong lúc 2 instance: `terraform plan -lock=false` → **No changes** (điều 4);
      `az webapp list-instances` thấy 2 instance; `m2-poll.sh` thấy cùng SHA
- [ ] C4. `load.sh` tự dừng ở phút 8 (hoặc dừng tay sớm nếu đã thấy 2 instance ≥ 2 phút — không cần
      đốt hết 8 phút). Ghi giờ dừng
- [ ] C5. Chờ scale in 2→1 (~10–20 phút). Suốt lúc đó **không** tạo tải, **không** merge
- [ ] C6. Về 1 instance → để `m2-poll.sh` chạy thêm 2 phút → dừng cả hai script theo pid đúng
      (`pgrep -f '^bash scripts/…'` + `ps -o args`, bài học `ai-failure-log.md` #33)
- [ ] C7. Activity Log: `az monitor activity-log list -g rg-vsf-dev --start-time … --query
      "[?contains(operationName.value,'autoscale') || contains(operationName.value,'Autoscale')]"` → lưu
      thô. Tìm sự kiện scale up / scale down + timestamp
- [ ] C8. 👤 Portal: Plan → Metrics (CPU Percentage, 30 phút) · Plan → Scale out → **Run history**
      (thấy 1→2 và 2→1) → chụp vào `evidence/d19/screenshots/`. Chưa chụp được → `notes/screenshot-debt.md`
- [ ] Nếu 9 phút tải mà vẫn 1 instance: **đừng** tăng tải hay kéo dài. Đọc metric CPU (có > 70%
      trung bình 5 phút không?) + `az monitor autoscale show` (đúng target/metric chưa?) → ghi
      `notes/d19.md` rồi mới quyết định chạy lại

## Pha D — Right sizing + ghi chép (không tốn thêm)

- [ ] Số đo plan (`az monitor metrics list --resource <plan id> --metric CpuPercentage MemoryPercentage
      --interval PT1H/PT1M --aggregation Average Maximum`):
      - **tải bình thường**: khoảng 24h trước D19 (môi trường đã bật liên tục từ 26/09, có CD + poll D18)
      - **lúc test tải**: khung Pha C
- [ ] Response time `/items`: 20 lần `curl` từ máy (ghi rõ gồm ~1s handshake WARP, tách bằng
      `time_starttransfer - time_appconnect`) + metric `HttpResponseTime` của web app `be` nếu có
- [ ] Bảng right sizing của guide (CPU/Memory/response time × trung bình/đỉnh) → kết luận tier kèm
      giá Central India ở trên. Dự kiến: giữ **P0v3** nếu memory đỉnh < ~70% và CPU bình thường thấp —
      để số đo quyết định, không để kỳ vọng quyết định
- [ ] `evidence/M7.md` (phần autoscale): cấu hình (JSON B2), timeline 1→2→1 (load log + watch log +
      Activity Log), kết quả M2 lúc scale, bảng right sizing, kết luận tier. Ghi rõ phần cost report để D20
- [ ] `notes/d19.md`: quyết định A–F, số liệu, thứ gì kế hoạch này nói sai
- [ ] `ai-failure-log.md` nếu có case mới · plan: tick D19 + Recovery · `known-issues.md` #21: nếu
      `m2-poll.sh` lúc scale có dữ liệu mới về TLS chậm thì cập nhật

## Pha E — Cuối phiên

- [ ] Xác nhận **capacity = 1**, không `load.sh` nào còn chạy (`pgrep -af 'scripts/load.sh'` rỗng),
      không run CD `in_progress`
- [ ] Nhắc chi phí (môi trường vẫn bật theo quyết định người dùng): P0v3 $0.082/giờ × số instance +
      MySQL B1ms + ACR Basic. Hỏi người dùng có muốn `make down` sau D19 không

---

## Bảng bẫy

| # | Bẫy | Hậu quả | Tránh |
|---|---|---|---|
| Q1 | Metric lấy từ Web App (`CpuTime`) thay vì Plan (`CpuPercentage`) | Rule không bao giờ kích hoạt, tưởng "autoscale chậm" | Điều 1; kiểm JSON B2: `metricResourceUri` kết thúc bằng `/serverfarms/asp-vsf-dev` |
| Q2 | Không `ignore_changes = [worker_count]` | `plan` drift khi đang 2 instance; `apply` lúc đó kéo về 1 giữa tải | Quyết định A; kiểm ở C3 |
| Q3 | `seconds` > `LOAD_MAX_SECONDS` (60) | 400 hàng loạt, CPU phẳng, tưởng autoscale hỏng | Script từ chối > 60; đọc cột `http_code` của load log trước khi nghi autoscale |
| Q4 | `curl --max-time` ≤ `seconds` | Mọi request tải đều timeout phía client, server vẫn đốt CPU → log tải toàn lỗi | `--max-time 75` với `seconds 55` |
| Q5 | Quên dừng tải / Ctrl+C không giết curl đang chờ | 2 instance cả buổi, tốn tiền | Trần 8 phút cứng; A4 đếm curl còn sống = 0; Pha E kiểm lại |
| Q6 | Tăng tải hoặc kéo dài vì "chưa thấy scale" | Vượt 8 phút, và vẫn không hiểu vì sao | Điều 2; nhánh chẩn đoán cuối Pha C |
| Q7 | Merge PR (= CD swap) trong lúc test tải | Swap + scale chồng nhau, log M2 không tách được nguyên nhân | Điều 5; C0 |
| Q8 | CPU bão hoà làm `/health` chậm → health check coi instance hỏng | Instance bị restart/thay giữa test, số đo méo | `Task.Run` đã tách luồng (LoadService); `m2-poll.sh` bắt được `/version` chậm; nếu có thì giảm xuống 2 worker ở lần chạy lại |
| Q9 | Timeout của `m2-poll.sh` qua WARP bị đọc thành "scale in gây lỗi" | Kết luận sai về tắt êm (đúng bẫy P3 của D18) | Đọc cột `t_connect`/`t_tls`/`t_ttfb`; so với baseline C1 |
| Q10 | Đặt maximum > 2 "cho chắc" | Vi phạm luật project + tốn tiền | Luật `CLAUDE.md`: tối đa 2 |
| Q11 | Apply từ nhánh chưa merge, hoặc từ nhầm thư mục | State lệch `main`, CI plan của PR sau báo diff lạ; `ai-failure-log.md` #11: `make up` thiếu `cd` vào worktree → apply nhầm code | B1: apply từ `main`, kiểm `pwd` + `git log -1` ngay trước lệnh |
| Q12 | Ngưỡng in quá gần ngưỡng out | Autoscale từ chối scale in (chống flapping), 2 instance mãi | 70/30 (điều 3); nếu 25 phút sau khi dừng tải vẫn 2 → đọc Activity Log trước khi sửa |

## Gợi ý trả lời 3 câu tự kiểm tra (guide)

1. **Vì sao max 2?** Luật project (ngân sách Free Trial $200, hết hạn 2026-10-15; mỗi instance P0v3
   $0.082/giờ). Với bài này, 2 là đủ để chứng minh cơ chế out/in; con số lớn hơn không chứng minh
   thêm gì mà tăng rủi ro chi phí nếu quên dừng tải.
2. **Flapping là gì, cấu hình nào chống?** Scale out rồi in rồi out liên tục vì tải dao động quanh
   ngưỡng. Chống bằng: khoảng cách rộng 70/30; cửa sổ in (10 phút) dài hơn out (5 phút); cooldown
   in 10 phút; và cơ chế ước tính "sau khi giảm có vượt ngưỡng out không" của autoscale (điều 3).
3. **Scale up vs scale out?** Up = đổi tier/SKU (máy to hơn, ví dụ P0v3 → P1v3; đổi ở
   `sku_name`, Terraform). Out = thêm instance cùng tier (autoscale D19, 1→2). Project dùng out để xử
   lý tải ngắn hạn, còn up là quyết định right sizing (Pha D). Ở D19 không scale up trừ khi số đo đòi.

## Ước lượng

| Pha | Thời gian | Tốn tiền |
|---|---|---|
| A — Terraform + 2 script + kiểm khô + PR | ~1.5 giờ | không (merge = 1 lần CD, vài phút build) |
| B — apply + kiểm | ~15 phút | autoscale setting không tính phí |
| C — tải 8 phút + chờ scale in | ~40 phút | instance thứ 2 ~30 phút ≈ $0.04 |
| D — right sizing + ghi chép | ~1 giờ | không thêm |
| E — kiểm cuối | ~5 phút | — |

## Lưu ý cho phiên có AI

- Kế hoạch do Claude Code (Opus 5.5) viết 2026-09-27, ngay sau khi chốt D18. Dữ kiện ở bảng "đã
  đọc từ repo" đều có file:dòng. Dữ kiện Azure (capacity, provider, giá) đọc bằng lệnh chỉ đọc cùng
  ngày — **Pha B đọc lại, không tin bảng này**.
- Luật phiên: `terraform apply`, test tải, merge PR phải hỏi người dùng. Lệnh `gh`/`az` chạy trần,
  không ghép `cd … &&`; vòng lặp shell phức tạp thì viết thành file `.sh` rồi chạy (guard worktree).
- Node 24 + .NET local: `export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$HOME/.nvm/versions/node/v24.21.0/bin:$PATH`.
- `terraform.tfvars` bị gitignore — worktree mới phải chép từ checkout chính (đọc trước khi chép).

# D25 — Kế hoạch chi tiết: demo 45 phút (live, không slide)

Guide gốc: `docs/guides/d25-demo.md` · Nhật ký: `notes/d25.md` (tạo khi chạy thử / demo) · Phiên trước: `notes/d24.md`
· Review trước demo: `notes/review-2026-10-01-sonnet.md`

> Viết 2026-10-01 tối, sau D24 + DevSecOps + sửa review 30/09 (#86–#89). Kịch bản dưới dựa trên số đo thật của
> các bài trước (CD ~11 phút, alert 5xx Fired ~4′40″ sau lỗi đầu, scale out ~6′35″ sau khi tải), không phải ước đoán.

## Đọc 60 giây này trước

| | |
|---|---|
| **Việc chính** | (A) Chuẩn bị không tốn tiền: kịch bản phút-theo-phút + lệnh (file này) · `scripts/demo-preflight.sh` (T−60, chỉ đọc) · cost report số 01/10 · (B) 👤 Chạy thử toàn bộ, bấm giờ (T−1 ngày) · (C) 👤 Demo live · (D) Sau demo: Cost analysis cuối, câu hỏi mentor → `known-issues.md`, plan → `completed/` |
| **Không làm** | `make down` → `make up` trước demo (PoC chung plan, #23 — môi trường `jcip0s` đang bật, preflight thay cho bước "`make up` T−60") · destroy live trong demo (M8 dùng log đã lưu) |
| **Tốn tiền?** | Chạy thử + demo: mỗi lần 1 CD swap (merge PR) + 2 swap ngược + `/load` 8 phút (instance thứ 2 ~12 phút ≈ $0,02) + `/boom` 8 phút. Nền: môi trường bật ≈ **$2,15/ngày** (`cost-report.md`) |
| **Ai chạy** | AI: soạn, kiểm chỉ đọc. 👤 Người dùng: mọi swap/apply/tải (auto mode chặn AI — memory "auto-mode-blocks-prod-ops") và toàn bộ demo |
| **Hạn cứng** | **Demo phải trước 15/10**: Free Trial hết hạn (Q5) **và** ngoại lệ `.trivyignore` CVE-2026-84782 hết hạn — sau ngày đó mọi PR/CD đỏ ở cổng Trivy nếu Microsoft chưa ra image vá (`known-issues.md` #31). Preflight mục 12 đếm ngày |
| **Xong khi** (guide) | chạy thử đủ kịch bản trong 45 phút · demo live xong · `make down` + Resources trống · cost report cập nhật · plan chuyển `completed/` |

## 0. Trạng thái 01/10 17:00Z (preflight lần đầu: 0 FAIL, 0 WARN)

`scripts/demo-preflight.sh --suffix jcip0s` (62 giây): subscription Enabled · `be`/`fe` production = `main` = `bb55a6a`,
staging = `bd2a4b2` · 4 bề mặt × 2 app Deny + scm dùng luật chính + 0 luật `cd-*` · IP máy trong whitelist · 3 KV reference
Resolved · ACR admin tắt · 3 alert bật, action group có 1 email, 0 alert Fired · autoscale max 2, plan 1 instance ·
workspace có log HTTP · CD cuối success · `.trivyignore` còn 13 ngày. INFO: PoC `app-obs-demo-jcip0s` vẫn trên plan.

## 1. Quyết định (người dùng chốt 02/10: "xem xét lại cái gì không cần thiết thì bỏ")

| # | Chốt | Vì sao |
|---|---|---|
| A | **Demo ≤ 14/10**, chạy thử T−1 ngày | Hạn cứng ở bảng trên (Free Trial + `.trivyignore`). Mentor chưa trả lời Q5 |
| B | **Giữ `jcip0s` bật**; T−60 chạy preflight thay `make up` | `make down` gãy khi PoC còn (#23); dựng lại ~15 phút + CD + đổi suffix → URL/whitelist đổi |
| C | **Rollback live ngay sau CD**: swap ngược `fe` rồi `be` trong lúc `m2-poll` vẫn chạy | Swap 39 giây/app (drill 2), tất định; cho thấy luôn "rollback cũng 0 non-200". Sau demo chạy lại CD để production = `main` |
| D | **Đo IP nơi demo T−1 ngày**; khác whitelist → sửa `terraform.tfvars` + apply (hỏi trước) | IP phòng họp ≠ IP nhà; WARP đổi IP (#19) |

**Bỏ:** M5 live (gỡ quyền KV → restart → trả quyền → restart): 2 `apply` + 2 restart, mất ~20 phút ở lần đo D12, lan
truyền RBAC không đoán được — rủi ro cao nhất buổi demo cho một mốc đã có bằng chứng đủ. Thay bằng 1 phút chỉ
`evidence/M5.md` (bảng 11 bước + JSON `AccessToKeyVaultDenied`) và biến `grant_app_keyvault_access` trong
`infra/app/keyvault.tf`. **Không phải quyết định, chỉ ghi lại:** `make down` sau demo chỉ chạy được khi PoC đã gỡ khỏi
`asp-vsf-dev`/`rg-vsf-dev`; khi PoC còn, ô "Resources trống" của guide không đạt được.

## 2. Checklist trước demo (lệnh cụ thể)

**T−1 ngày** (chạy thử, bấm giờ — ghi `notes/d25.md`)
- [ ] `git pull` checkout chính; `cd infra/app && terraform plan` → **No changes** (kiểm luôn `terraform.tfvars` của checkout
      này có `alert_email` và IP nơi demo — thiếu `alert_email` thì một lần apply bất kỳ (vd sửa IP, quyết định D) sẽ
      **xoá email receiver**).
- [ ] Đo IP nơi demo (quyết định D).
- [ ] Chuẩn bị PR deploy (mục 3.2) — **mở trước để CI xanh sẵn**, không merge.
- [ ] Chạy thử toàn bộ mục 3 theo giờ, ghi lệch giờ thật vs dự kiến.
- [ ] Lúc chạy thử mục 3.1: **chụp ảnh nút merge bị khoá** → `evidence/d25/screenshots/` + link từ `evidence/M9.md` (ảnh còn nợ
      duy nhất của M9 — review Sonnet P1-1; ảnh gitleaks đỏ đã có từ #85).
- [ ] Sau chạy thử: production về lại `main` (`gh workflow run cd.yml --ref main` hoặc merge PR kế tiếp), preflight lại.
- [ ] Bằng chứng dự phòng mở sẵn trong trình duyệt (mục 4).

**T−60 phút**
- [ ] `scripts/demo-preflight.sh --suffix jcip0s --out evidence/raw/d25-preflight-<giờ>.txt` → **0 FAIL**. WARN alert Fired
      → đợi Resolved; WARN workspace trống → mở `fe` bấm vài trang, đợi 5 phút.
- [ ] Điện thoại: tắt Wi-Fi, 4G vào được `https://example.com` (để phần M6 ra 403 của **whitelist**, không phải lỗi mạng).
- [ ] Mở sẵn tab: repo + PR deploy · Actions · ruleset `protect-main` · Portal: `app-vsf-jcip0s` (Deployment slots, Access
      restrictions, Environment variables), ACR (Access keys), Key Vault (Access control), MySQL (Networking), Alerts,
      Workbook `M11`, Autoscale Run history, Cost analysis · hộp thư email alert · `runbook.md`.
- [ ] 4 terminal, chữ to: (1) `m2-poll` · (2) `boom` · (3) `load` · (4) lệnh tay. Biến dùng chung:
      `export S=jcip0s BE=https://app-vsf-jcip0s.azurewebsites.net FE=https://fe-vsf-jcip0s.azurewebsites.net`
- [ ] **T−10 phút**: terminal (1) bật `scripts/m2-poll.sh --be-url $BE --fe-url $FE` (cần ≥ 60 giây baseline trước merge).

**T−5 phút**
- [ ] Tắt thông báo; đóng password manager; **che email** (Portal header, hộp thư — chỉ mở đúng thư alert).
- [ ] `git status` sạch, đứng ở `main`.

## 3. Kịch bản phút-theo-phút

Nguyên tắc của guide: phần chờ lâu (CD ~11 phút, alert ~5 phút, scale out ~6,5 phút) **kích hoạt sớm**, nói phần khác trong
lúc chờ. Thứ tự dưới khác bảng guide ở chỗ đó; nội dung M1–M11 đủ.

| Phút | Phần | Làm gì (lệnh / màn hình) | Chứng minh | Dự phòng nếu hỏng |
|---|---|---|---|---|
| 0–3 | Mở đầu | README (bảng tài liệu) → `architecture.md`: sơ đồ traffic, sơ đồ auth | bức tranh tổng | — |
| 3–4 | **Kích hoạt CD** | Mở PR deploy (mục 3.2, đã xanh) → **Squash merge** → Actions: run CD bắt đầu | M10 | CD đỏ: mở log job, nói nguyên nhân, dùng `evidence/M10.md` |
| 4–9 | CI chặn cái sai | Mục 3.1: hook gitleaks chặn commit ở máy → `--no-verify` → push → PR → job `gitleaks` đỏ (~1 phút) → nút merge xám (`mergeable_state = blocked`) → ruleset `protect-main` (9 required check) → **đóng PR, xoá nhánh** | M9 | CI chậm: ảnh `evidence/d14/screenshots/m9-pr34-gitleaks-red-…png` + bảng 5 PR đỏ, JSON `blocked` (`evidence/M9.md`) |
| 9–15 | Container + identity (trong lúc CD chạy) | ACR → Access keys: Admin user **tắt** · `be` → Identity: user-assigned `id-vsf-<s>`; `fe` có identity riêng (#87) · `az webapp config show --query acrUseManagedIdentityCreds` = `true`; `az webapp config container show`: `DOCKER_REGISTRY_SERVER_PASSWORD` = null, username rỗng (đo 01/10) · quay lại Actions: preflight → build/Trivy → deploy staging → smoke `/items` → swap | M1 | `evidence/M1.md` |
| ~15 | **CD xong** | Terminal (1): sha đổi A→B ở `be` trước, `fe` sau ~95 giây. `curl $BE/version` = SHA merge | M2, M10 | — |
| 15–18 | **Rollback live** | Terminal (4): 2 lệnh swap ngược (runbook mục Rollback, `fe` trước rồi `be`) — 👤 người dùng gõ. Terminal (1): B→A. **Ctrl+C** `m2-poll` → tóm tắt: 0 non-200 | M2, rollback | `evidence/M2.md` (4 lần swap, 0 non-200) · `docs/drills/2026-10-01-bad-deploy.md` |
| 18 | **Kích hoạt tải + lỗi** | Terminal (2): `scripts/boom.sh --be-url $BE --duration 480` · Terminal (3): `scripts/load.sh --url $BE --workers 3 --seconds 55 --duration 480` | — | — |
| 18–21 | DB + secret | `fe` tạo 1 ticket (POST) → danh sách (GET) · Portal Environment variables: `DB_PASSWORD` = Key Vault reference, **Resolved** (cả slot staging) · MySQL Networking: firewall đúng outbound IP, "Allow Azure services" tắt, TLS bắt buộc | M3, M4 | `evidence/M3.md`, `M4.md` |
| 21–25 | IP whitelist | Laptop: `curl -s -o /dev/null -w '%{http_code}\n' $BE/health` = 200 · điện thoại 4G mở `$FE` → trang 403 · Portal Access restrictions: Unmatched = Deny, tab Advanced tool site "Use main site rules" | M6 | `evidence/M6.md` (8 bề mặt) |
| 23–25 | Alert bắn (~phút 23) | Alerts: `alert-vsf-5xx-rate` **Fired** (Sev1) → mở email → runbook bước 1–3: KQL theo path `/boom` → lấy `trace_id` → log JSON cùng `trace_id` → App Insights end-to-end transaction | M11 | Alert chưa tới: đi tiếp, quay lại ở phút 33. Ảnh email `evidence/d24/screenshots/alert-email-*.png`; `evidence/M11.md` mục 6 |
| 25–31 | Autoscale | Autoscale Run history: Scaleup (~phút 24–25, 1→2) · metric CPU Percentage của plan · nhắc max **2**, scale in sau 10 phút · right sizing giữ P0v3 | M7 | `evidence/M7.md` (1→2 sau 6′35″, ảnh D19) |
| 31–36 | Quan sát | Workbook `M11`: 5 hàng (request/failure/latency · CPU/memory · MySQL · trace · alert) · 2 KQL từ `docs/logging.md` mục 3 (p95 theo path, lỗi theo path) · log JSON trong `AppServiceConsoleLogs` | M11 | `evidence/d21|d22/screenshots/` |
| 36–41 | Terraform + M5 | Terminal (4): `cd infra/app && terraform plan` live → **No changes** (state ở storage bootstrap, Entra-only; lock = blob lease) · `drift.yml` theo lịch (run gần nhất) · `evidence/M8.md`: D10 destroy → apply, lần cuối clone mới · M5: `evidence/M5.md` bảng 11 bước + biến `grant_app_keyvault_access` | M8, M5 | plan chậm/lease kẹt: `evidence/M8.md`; **không** `force-unlock` giữa demo |
| 41–45 | Chi phí + bài học | Cost analysis (lọc tag `project = vsf`) · `cost-report.md`: 3 biện pháp + "nói thật biện pháp 1" · `known-issues.md` (Chưa xong #5–#7, #33) · 1–2 case `ai-failure-log.md` (vd #43 import state suýt thay `random_string`) | M7 | — |

Sau giờ demo (không trước mặt mentor): production đang ở SHA cũ (sau swap ngược) → `gh workflow run cd.yml --ref main`
hoặc merge PR ghi chép `notes/d25.md` → production = `main`; preflight lại.

### 3.1 PR secret giả (M9, tạo live)

Token **sinh lúc demo**, không nằm trong repo (file này cũng bị gitleaks quét):

```bash
git switch -c test/d25-m9-secret main
printf 'GITHUB_TOKEN=ghp_%s\n' "$(openssl rand -hex 18)" > demo-leak.env   # 36 ký tự hex — khớp luật github-pat
git add demo-leak.env && git commit -m "test: secret giả (D25 demo)"        # lớp 1: hook pre-commit chặn
git commit --no-verify -m "test: secret giả (D25 demo)"                    # cố tình vượt lớp 1
git push -u origin test/d25-m9-secret
gh pr create --title "test(d25): KHÔNG MERGE — secret giả cho demo M9" --body "Token ngẫu nhiên, không phải credential. Đóng ngay sau demo."
# sau khi thấy đỏ + bị khoá:
gh pr close --delete-branch && git switch main && git branch -D test/d25-m9-secret
```

Token là chuỗi ngẫu nhiên, nhưng vẫn coi như đã lộ: không tái sử dụng chuỗi đó ở đâu khác. Lịch sử nhánh xoá cùng PR.

### 3.2 PR deploy (mở T−1 ngày, merge ở phút 3)

Thay đổi nhỏ **nhìn thấy được** để người xem thấy bản mới lên: chữ tiêu đề `OpsBoard` trong
`app/fe/src/components/AppHeader.tsx:25` → `OpsBoard · D25`. Nhánh `feat/d25-demo-header`, PR có mục `## AI usage`
(luật repo). Merge = 1 lần CD swap thật (hỏi trước — nằm trong lần chạy thử/demo người dùng đã duyệt). Nhánh sống ≤ 2 ngày:
mở **T−1 ngày**, không sớm hơn.

## 4. Bằng chứng dự phòng (mở sẵn tab)

| Phần | File |
|---|---|
| M9 | `evidence/M9.md` (5 PR đỏ `blocked` + ảnh gitleaks đỏ PR #34) |
| M10 / rollback | `evidence/M10.md` (D16, D17 C1–C4) · `docs/rollback.md` · `docs/drills/` |
| M2 | `evidence/M2.md` + `evidence/raw/m2-*.log` |
| M1, M3–M6 | `evidence/M1.md`, `M3.md`–`M6.md` |
| M7 | `evidence/M7.md` (Run history 1→2→1) · `cost-report.md` |
| M11 | `evidence/M11.md` (alert Fired/Resolved, email, Workbook) · `evidence/tracing.md` · `runbook.md` |
| M8 | `evidence/M8.md` (D10 destroy → apply; lần cuối clone mới) |

## 5. Rủi ro đã biết

| Rủi ro | Xác suất | Giảm thiểu |
|---|---|---|
| CD > 15 phút (runner chậm, Trivy DB tải lâu) | thấp (6 run gần nhất 10–12 phút) | phần M1/M3/M4 không phụ thuộc CD — đổi thứ tự, rollback để cuối |
| Timeout client trong `m2-poll` qua WARP (#21) | trung bình | tắt WARP nếu IP nơi demo nằm trong whitelist không cần WARP; nói thật: 0 non-200, timeout là đường mạng client (M2.md) |
| Alert không bắn trong 8 phút (cần > 5% 5xx **và** ≥ 20 request / 10 phút) | thấp (2/2 drill bắn sau ~4′40″) | `--duration 480` phủ ≥ 1 lần đánh giá; quay lại ở phút 33 |
| `/load` + `/boom` cùng lúc làm request `/boom` chậm | thấp | boom tuần tự, request chậm thì đi tiếp ngay; tỉ lệ 5xx không đổi |
| PoC trên plan chung ăn CPU lúc `/load` | thấp | PoC chỉ ghi OTEL, đo D24 không ảnh hưởng; không đụng PoC (memory "poc-must-not-be-affected") |
| IP nơi demo đổi giữa giờ (WARP, 4G) | trung bình | "Tự nhận 403" trong guide: sửa biến + apply — vừa demo cả quy trình |

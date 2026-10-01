# D24 — Kế hoạch chi tiết: incident drill · kiểm README từ clone mới · hoàn thiện tài liệu

Guide gốc: `docs/guides/d24-drill-finalize.md` · Nhật ký: `notes/d24.md` (tạo khi làm) · Postmortem: `docs/drills/`
· Phiên trước: `notes/d23-prep.md` · Bài sau: D25 demo (`docs/guides/d25-demo.md`)

> Viết 2026-09-30 cùng lúc với D23. Làm **sau** D23 vì README và `architecture.md` phải có danh tính agent.

## Đọc 60 giây này trước

| | |
|---|---|
| **Việc chính** | (A) Tài liệu: README viết lại · `architecture.md` về gốc repo · known-issues · ai-failure-log (8 case tiêu biểu) · `test-report.md` · `docs/rollback.md` · (B) Kiểm README từ **clone mới** (không destroy) · (C) **2 drill** có timeline + postmortem · (D) Soát evidence M1–M11 |
| **Không làm** | `make down` → `make up` (người dùng chốt 30/09: **giữ PoC** trên plan chung, #23) · MySQL point-in-time restore (tạo thêm server, không đáng) · 5 file tài liệu riêng theo brief: gộp vào README + các file sẵn có (quyết định C) |
| **Tốn tiền?** | Gần 0, không tạo resource mới. Khoảng 3–4 lần **CD swap** (PR drill, PR revert, 1–2 PR tài liệu) + 1 swap tay + 1 apply phục hồi + 1 `make up` idempotent |
| **Ai chạy** | AI: soạn kịch bản, **tự gây sự cố và tự xử lý** (người dùng chốt 30/09), viết tài liệu. 👤 Người dùng duyệt từng bước tốn tiền hoặc đụng production |
| **Xong khi** (guide) | 2 drill có timeline + postmortem · dựng lại từ clone mới theo README (**bản không destroy**, ghi rõ giới hạn) · README, architecture (2 sơ đồ), known-issues, ai-failure-log ≥ 6, evidence M1–M11 · ~~`make down`~~ (người dùng quyết cuối D24) |

## Quyết định (người dùng chốt 30/09)

| # | Quyết định | Hệ quả phải ghi thật |
|---|---|---|
| A | **Giữ PoC `app-obs-demo-jcip0s`**, không `make down` | M8 lần cuối = clone mới → `plan` No changes → `make up` 0 thay đổi. **Không** có destroy → apply cho hạ tầng tuần 3–5 (`fe`, alert, Workbook, agent). Ghi vào `evidence/M8.md` và `known-issues.md` mục "chưa xong" |
| B | Drill do **Claude tự soạn, tự gây, tự xử lý**, báo trước | Không kiểm được phát hiện "mù". Postmortem ghi rõ giới hạn này |
| C | Tài liệu brief (deploy · vận hành · rollback · troubleshooting · kiểm thử) **không** thành 5 file mới | README có bảng trỏ: deploy = README · vận hành = `runbook.md` + `docs/logging.md` · troubleshooting = `known-issues.md` · rollback = `docs/rollback.md` · kiểm thử = `test-report.md` |

## Pha A — Tài liệu (không tốn tiền, nhánh `docs/d24-finalize`)
- [ ] **`README.md` viết lại** (hiện 44 dòng) theo guide mục C:
  - tổng quan 3 dòng + link `architecture.md`
  - prereq: Owner hoặc tương đương, provider cần register (`notes/d1.md`), phiên bản Terraform, az, Docker, gitleaks, Trivy (lấy từ `ci.yml`, `versions.tf`)
  - bootstrap một lần: state storage, `id-gh-plan`/`id-gh-deploy`/`id-agent-triage`, federated credential, GitHub environments `staging-deploy`/`production`/`agent-triage`, GitHub variables
  - bảng biến: `terraform.tfvars.example` + GitHub vars, **không có giá trị thật**
  - việc hằng ngày: `make up`, `make down`, `make check-empty`
  - luồng PR → CI → merge → CD
  - teardown hoàn toàn: cảnh báo mất state, purge KV, xoá federated credential, gỡ PoC trước (#23)
  - troubleshooting: trỏ tới `known-issues.md`, `runbook.md`
  - bảng tài liệu theo brief (quyết định C)
- [ ] **`architecture.md` ở gốc:** `git mv docs/docs_app/architecture.md architecture.md`, sửa mọi link trỏ tới đường dẫn cũ (`grep -rn "docs_app/architecture"`). Hai sơ đồ mermaid **tách biệt**: (1) traffic (IP whitelist → `be`/`fe` × slot → MySQL firewall; GitHub → ACR → staging → swap); (2) auth (OIDC → 3 danh tính CI/CD/agent; MI app → AcrPull / KV Secrets User; Terraform → Secrets Officer / Blob Data Contributor). Mỗi mũi tên ghi giao thức, danh tính và role. Bảng danh tính → role → scope lấy từ `az role assignment list` **thật**.
- [ ] **`known-issues.md`:** rà 3 mục theo đề. #17 → đã sửa (D23). Thêm "cross-review × 2 chưa làm" và "M8 lần cuối không destroy" vào mục chưa xong.
- [ ] **`ai-failure-log.md`:** giữ nguyên các case hiện có. Thêm bảng **"8 case tiêu biểu để nộp"** ở đầu file: yêu cầu · sai ở đâu · phát hiện bằng gì · link case.
- [ ] **`test-report.md`:** kịch bản (health · M2 zero-downtime · M6 whitelist · M7 autoscale · M9 CI chặn · M10 CD/swap an toàn · M11 alert · agent · 2 drill · rollback) → kết quả → link evidence/run → ngày.

## Pha B — Kiểm README từ clone mới, không destroy
1. `git clone` vào `~/vsf-fresh`. Làm **đúng từng bước README**, không dùng trí nhớ: kiểm phiên bản công cụ → `az login` → tạo `terraform.tfvars` từ `.example` → `terraform init`. Bước nào thiếu hoặc sai thì sửa README trong PR (ghi lại từng chỗ sửa).
2. [ ] `terraform plan` app + bootstrap từ clone mới = **No changes**.
3. [ ] **Cần duyệt:** `make up` từ clone mới. Mong đợi 0 thay đổi (idempotent).
4. [ ] Dispatch CD từ `main` → `/version` và `/api/version` = SHA `main` · `m6-check.yml` 8/8 · agent `mode=triage` xanh.
5. [ ] `evidence/M8.md` thêm mục "Lần cuối (D24)": log thật, kèm dòng giới hạn (quyết định A).

## Pha C — 2 incident drill (duyệt từng drill)

Chuẩn bị chung:
- `scripts/boom.sh` thêm `--path` (mặc định `/boom`, không đổi hành vi cũ) để tạo traffic nền `GET /items`. Nhịp tối đa 1/giây, đủ ≥ 20 request / 10 phút cho `alert-vsf-5xx-rate`.
- Watcher **chỉ đọc**, 30 s/lần: `/health` be + fe, trạng thái alert qua Resource Graph (`alertsmanagementresources`, mẫu ở `notes/d22.md`). Ghi TSV vào `evidence/raw/`, dùng làm timeline.
- Chụp trạng thái trước: danh sách firewall rule (`az mysql flexible-server firewall-rule list`), SHA đang chạy, slot.

### Drill 1 — drift hạ tầng: mất firewall MySQL (kịch bản C của guide)

| Bước | Việc | Mong đợi |
|---|---|---|
| T0 | **Cần duyệt:** xoá các rule `app-outbound-*` bằng `az` (nếu Bash guard chặn `delete`, dừng lại và nhờ người dùng chạy đúng lệnh đó) | — |
| T+~1' | `/health` 503 · `/items` 503 (`database_unavailable`) | watcher thấy |
| T+~5' | `alert-vsf-5xx-rate` Fired | Resource Graph |
| chẩn đoán | agent `mode=triage` + runbook bước "phân loại": lỗi DB → so outbound IP của app với firewall | chỉ ra rule thiếu |
| xử lý | `terraform plan` thấy N rule to add → **cần duyệt** `apply` | `/health` 200 |
| kết thúc | `plan` = No changes · alert Resolved (~25 phút theo D22) | TTD, MTTR |

### Drill 2 — deploy lỗi → swap ngược (kịch bản A của guide)

| Bước | Việc | Mong đợi |
|---|---|---|
| chuẩn bị | PR `drill: GET /items trả 500` (`/health` vẫn 200). Test `be` phải đỏ cho đúng hành vi mới, nên PR **sửa kèm test**, đánh dấu rõ là drill. PR có `## AI usage` | CI xanh |
| T0 | **Cần duyệt:** merge → CD swap (cổng CD chỉ nhìn `/health`, nên **không chặn được**: đây là phát hiện cần chứng minh) | `/items` 500 trên production |
| T+~5' | alert 5xx Fired → Workbook → `trace_id` → log exception | đúng dòng code |
| xử lý | runbook: **cần duyệt** swap ngược slot `be` (`az webapp deployment slot swap`) → `/items` 200 → đo **RTO** | — |
| dọn | PR revert → **cần duyệt** merge → CD → production = bản tốt, cả 2 slot | `/version` = SHA revert |

### Sau mỗi drill
- Postmortem không đổ lỗi → `docs/drills/<ngày>-firewall.md`, `docs/drills/<ngày>-bad-deploy.md`. Nội dung: tóm tắt, tác động, timeline, nguyên nhân gốc, làm tốt, chưa tốt, action item.
- Action item sửa được thì sửa runbook qua PR. Ứng viên: cổng CD chỉ kiểm `/health`, nên thêm smoke `/items` trên staging trước swap (**chỉ đề xuất**, không tự làm: đổi hành vi CD cần người dùng duyệt).
- `docs/rollback.md`: 4 kịch bản phục hồi, mỗi dòng có thời gian đo được và link. Swap ngược = drill 2. Khôi phục quyền KV = M5 (D12). Drift → apply = drill 1. Clone mới → plan No changes = Pha B. PITR: không làm, ghi lý do.

## Pha D — Soát và đóng
- [ ] `evidence/README.md`: bảng M1–M11 (log/ảnh thật? · link run/PR · ngày). 5 ảnh Portal còn nợ: ghi rõ còn nợ hay bỏ.
- [ ] Kiểm link tài liệu: không còn link tương đối trỏ tới file không tồn tại.
- [ ] Plan: Tiến độ, bảng mốc, D24 ✅. `notes/d24.md`.
- [ ] **Hỏi người dùng:** `make down` hay giữ môi trường tới D25. Free Trial hết hạn **15/10** (Q5 chưa có trả lời).

## Cần duyệt (hỏi đúng lúc)
1. Merge PR tài liệu (CD swap) · 2. `make up` idempotent từ clone mới · 3. Drill 1: xoá firewall + apply phục hồi ·
4. Drill 2: merge PR lỗi, swap ngược tay, merge PR revert.

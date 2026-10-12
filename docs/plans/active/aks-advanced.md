# AKS — phần ADVANCED (ngoài phạm vi `topic.md`)

**Status:** active
**Opened:** 2026-10-12
**Goal:** Cùng app OpsBoard chạy thêm trên AKS, song song với App Service: `make aks-up` dựng từ rỗng,
merge vào `main` tự deploy, đủ bằng chứng tương đương M1–M11 trong `evidence/advanced/`.

Người dùng yêu cầu 12/10: làm thêm AKS, làm ngay, đủ 4 khối (bảo mật · CD + zero-downtime ·
autoscale + chi phí · monitoring), ghi rõ trong evidence là phần advanced, và
**chỉ thêm — không đụng những thứ đã có/đã làm**. Không chia lịch theo ngày: làm liền một mạch.
Sau P0–P2 và sau P3–P5: viết prompt + chạy sub-agent Sonnet review (`docs/prompts/aks-review-*.md`).

## Authority

- Không có trong `topic.md`. Authority là yêu cầu của người dùng trong phiên 12/10 và file này.
- Luật project `CLAUDE.md` vẫn áp dụng nguyên: tốn tiền = hỏi trước, autoscale tối đa 2, không để
  qua đêm, không push `main`, mỗi PR có `## AI usage`, AI sai → `ai-failure-log.md`.
- Hạn cứng: subscription Free Trial hết hạn **2026-10-15**. Demo bài chính (≤ 14/10) được ưu tiên.

## Sự thật đã xác minh 12/10 (az chỉ đọc)

| Sự thật | Hệ quả |
|---|---|
| Quota 4 vCPU/region, không tăng được. Central India 4/4 đã dùng (2 VM của PoC) | Không dựng ở Central India |
| Southeast Asia: D-series `NotAvailableForSubscription` cấp Location | Không dựng ở Southeast Asia |
| East Asia: D2as_v5 không hạn chế, cores 0/4, public IP 0/3 | **Region = `eastasia`** |
| B-series không được làm system pool | Node `Standard_D2as_v5` |
| Managed NGINX (app routing) hết hỗ trợ 11/2026; Gateway API chưa tự lo TLS | Không ingress controller, dùng Service LoadBalancer |
| Mỗi merge vào `main` = một lần swap thật trên App Service (`cd.yml` không path filter) | Gom PR, hỏi trước mỗi lần merge |

## Decisions

- **A.** Root module mới `infra/aks`, state riêng `aks.tfstate`. Tra resource của `infra/app` bằng
  data source theo tên; hậu tố suy từ tên ACR (không truyền biến, không `terraform_remote_state`).
- **B.** RG `rg-vsf-aks`, cluster `aks-vsf-dev`, tier Free, Kubernetes 1.35.
- **C.** 1 node pool `Standard_D2as_v5`, cluster autoscaler 1–2 (= trọn 4 vCPU). Không còn quota
  cho surge → tắt kênh tự nâng cấp.
- **D.** Azure CNI Overlay + Cilium; NetworkPolicy: `be` chỉ nhận từ `fe` (và API server để đo).
- **E.** Chỉ `fe` lộ ra ngoài: Service LoadBalancer + `loadBalancerSourceRanges`, **HTTP không TLS**.
- **F.** API server: `authorized_ip_ranges`, tắt local account, Entra + Azure RBAC. Danh sách IP rỗng
  ép về `0.0.0.0/32` (khoá, không mở).
- **G.** Secret: Workload Identity + add-on Key Vault CSI → `secretObjects` → env. Identity riêng
  `be`/`fe`, role ở scope **secret**.
- **H.** Database riêng `appdb_aks` trên MySQL hiện có; 1 firewall rule cho IP outbound của cluster.
- **I.** Monitoring tách hẳn: workspace + App Insights riêng (30 ngày, cap 0,2 GB/ngày như D20).
  Action group `ag-vsf-oncall` chỉ tham chiếu.
- **J.** `make aks-deploy` sở hữu mọi object K8s; CD chỉ đổi tag image. Giá trị riêng môi trường
  render lúc deploy từ `terraform output` (`scripts/aks-render.sh`), không vào git.
- **K.** `cd-aks.yml` chạy sau khi "CD" xanh (`workflow_run`), `kubectl` qua `az aks command invoke`.
- **L.** Danh tính `id-gh-aks-deploy` ở `infra/bootstrap/aks.tf`; quyền trên cluster ở `infra/aks`.
- **N (12/10, sau phép đo).** `be`/`fe` chạy **2 bản + PodDisruptionBudget** (`minAvailable 1`), HPA `be` min 1 → 2: với 1 bản,
  node thứ hai (do pod tạm 200m của `command invoke` + pod surge kéo lên ở mỗi lần deploy) bị gỡ là mất bản duy nhất —
  đo được `be` 503 trong 9 giây. Lý do và các đường đã bỏ: `docs/aks.md` mục 6.
- **M (12/10, lúc làm).** `prevent_deletion_if_contains_resources = false` cho riêng root này: App
  Insights tự sinh rule Smart Detection ngoài Terraform, để `true` thì `make aks-down` gãy.

## Ranh giới "không đụng"

- Không sửa: `infra/app/**`, `cd.yml`, `ci.yml`, `drift.yml`, `app/**`, script cũ, ruleset, `.trivyignore`, PoC.
- Chỉ thêm resource con ở state mới: ACR (+1 role) · MySQL (+1 database, +1 firewall rule) ·
  Key Vault (+1 secret, +3 role scope secret) · bootstrap (+1 identity, +2 federated credential,
  +1 custom role chỉ đọc) · storage state (+1 blob).
- File cũ chỉ nối thêm cuối: `Makefile`, `README.md`, `evidence/README.md`, `known-issues.md`,
  `ai-failure-log.md`, `cost-report.md`, `architecture.md`, `CLAUDE.md`, plan chính.
- `make aks-down` **trước** `make down`.
- Chốt chặn sau mỗi pha: `terraform -chdir=infra/app plan` → No changes · `scripts/demo-preflight.sh` → 0 FAIL.

## Tiến độ

- [x] **P0** — baseline 12/10 03:58Z: `infra/app` plan **No changes**, preflight **0 FAIL / 1 WARN**
      (`.trivyignore` còn 2 ngày); cài `kubectl` 1.36.4 + `kubelogin` 0.2.21 vào `~/.local/bin`.
- [x] **P1** — `infra/bootstrap` 5 added; `infra/aks` **27 added, 0 changed, 0 destroyed** (10 phút 14 giây), plan lần
      hai No changes → `evidence/advanced/aks-m8.md` (destroy → apply lại: để P7).
- [x] **P2** — 12 object, `be`/`fe` Ready sau 21 giây; `make aks-verify` 0 FAIL → `aks-m1.md`, `aks-m3.md`, `aks-m4-m5.md`.
      Chốt chặn sau P2: `infra/app` No changes, preflight 0 FAIL.
- [x] Review Sonnet lần 1 (P0–P2) — NO-GO có điều kiện; đã sửa #1 (IP trong log), #2 (rollback CD), #3 (environment
      `aks-deploy` + biến), #4 (bỏ `pods/exec`), #5–#8; #9–#12 ghi `known-issues.md` A1–A11.
- [x] **P3** — M5: gỡ 3 role → `FailedMount 403 ForbiddenByRbac` → `/api/health` 503 → trả quyền → tự hồi phục.
      M1 ngược: gỡ `AcrPull` → `ErrImagePull 401` → alert `pod-not-starting` **Fired 05:10:27Z** → trả quyền.
      NetworkPolicy: pod lạ → `be` timeout. Còn: M6 từ runner GitHub (cần workflow trên `main`).
- [x] **P4** — PR #94 11/11 check; `CD — AKS` tự chạy sau `CD`: lần đầu đỏ + rollback oan (bước kiểm trúng pod cũ, #54) →
      PR #96 → run `38219139675` **success**; nhánh rollback thử bằng `simulate_verify_failure`. `m2-poll`: 0 non-200 qua mọi
      lần rollout, nhưng **gián đoạn ~12 giây khi gỡ node** → Decision N. M6 từ runner: 2/2 bề mặt bị chặn → `aks-m9-m10-m2.md`, `aks-m6.md`.
- [x] **P5** — HPA `be` 1→2 sau 62 giây tải, về 1 sau 6 phút 34 giây; cluster autoscaler 1→2 node (45 giây tới Ready),
      tự gỡ node thừa sau 12 phút; right sizing request 100m/50m; chi phí niêm yết ≈ $3,9/ngày → `aks-m7.md`, `cost-report.md`.
      Còn: Actual cost (Cost analysis trễ 8–24 giờ).
- [x] Review Sonnet lần 2 (P3–P6, `docs/prompts/aks-review-2.md`) — GO có điều kiện, không P0. Đã sửa: lưu event trước-sửa vào
      `evidence/raw/` (chúng hết hạn sau ~1 giờ), tách "có bằng chứng" khỏi "suy luận" trong chuỗi nguyên nhân, bỏ câu
      "không gián đoạn" (mới đo 1 lần, mỗi node một bản), sửa lập luận chi phí (90% chênh lệch là do region, không phải một
      nửa), các mốc thời gian lệch vài giây; thêm `known-issues.md` A15–A18.
- [x] **P6** — dữ liệu về workspace riêng; 2 alert **Fired thật** (pod-not-starting 05:10:27Z, 5xx 07:28:35Z); truy vết
      alert → log → trace bằng `trace_id` → `aks-m11.md`. Còn: ảnh Workbook, ảnh email.
- [ ] **P7** — evidence, tài liệu, destroy → apply lần cuối, `make aks-down`

## Recovery

- 2026-10-12 08:25Z: `main` = `5b76360` (#94, #95, #96 đã merge; CD-AKS run `38219139675` xanh). PR #97 mở (2 bản + PDB + bằng
  chứng M6/M9/M10/M2/M11), 11/11 check. Cluster ĐANG BẬT: 1 node, `be`/`fe` 2 bản, `5b76360`. Còn lại: merge #97 → P7
  (destroy → apply lần cuối, `make aks-down`), Actual cost (từ 13/10), ảnh Workbook + email.
- 2026-10-12 07:02Z: CI của #94 lộ CVE HIGH mới ở `sharp` (image `fe`, không liên quan AKS) → người dùng chọn PR riêng:
  **#95 merge 06:48Z**, CD `38214392331` success, production = `ec8fde8`. `feat/aks-infra` đã merge `main` vào.
  Cluster 1 node, không còn namespace thử. Bước tiếp: CI #94 xanh → bật `m2-poll.sh` → merge #94.
- 2026-10-12 05:15Z: PR #94 mở (`feat/aks-infra`), cluster ĐANG BẬT, plan `infra/aks` No changes, mọi role đã trả lại.
  GitHub: environment `aks-deploy` (chỉ `main`) + biến `AZURE_CLIENT_ID_AKS_DEPLOY` đã tạo.
  Bước tiếp: CI xanh → bật `scripts/m2-poll.sh` → merge → CD (swap App Service) → `cd-aks.yml` chạy lần đầu.
- 2026-10-12: nhánh `feat/aks-infra`. Bootstrap apply **5 added, 0 changed, 0 destroyed** (plan sau:
  No changes). `infra/aks` plan **27 to add, 0 to change, 0 to destroy** → apply, log
  `evidence/raw/aks-apply-2026-10-12.log`.

## Validation

```
make lint test fe-lint fe-test fe-build
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra/aks validate && make aks-plan
terraform -chdir=infra/app plan            # No changes — chưa đụng cái cũ
scripts/demo-preflight.sh --suffix jcip0s  # 0 FAIL
kubectl kustomize k8s/base | kubeconform -strict -skip SecretProviderClass -
trivy config --severity HIGH,CRITICAL --exit-code 1 .
shellcheck scripts/aks-*.sh
make aks-verify
```

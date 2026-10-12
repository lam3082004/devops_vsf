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
- [ ] **P1** — Terraform `infra/aks` + `make aks-*` → M8
- [ ] **P2** — manifest + app chạy → M1, M3, M4
- [ ] Review Sonnet lần 1 (P0–P2)
- [ ] **P3** — chứng minh ngược → M1, M5, M6
- [ ] **P4** — CI + CD + zero-downtime → M9, M10, M2
- [ ] **P5** — autoscale + chi phí → M7
- [ ] Review Sonnet lần 2 (P3–P5)
- [ ] **P6** — monitoring + alert + trigger thật → M11
- [ ] **P7** — evidence, tài liệu, destroy → apply lần cuối, `make aks-down`

## Recovery

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

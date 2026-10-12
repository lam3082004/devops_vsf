# AKS · tương đương M9 + M10 + M2 — CI, CD, zero-downtime

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng của đề bài là [`../M9.md`](../M9.md), [`../M10.md`](../M10.md),
> [`../M2.md`](../M2.md).

Ngày: 2026-10-12 · log thô: `../raw/aks-cd-run-*.log` · `../raw/aks-m2-2026-10-12-run*.log`

## M9 — CI chặn được cái sai

Phần AKS không sửa `ci.yml` và không thêm required check (ruleset `protect-main` giữ nguyên 9 check). Hai lớp:

| Lớp | Cái gì | Bằng chứng nó **chặn** thật |
|---|---|---|
| Cổng chung sẵn có, tự phủ file mới | gitleaks · `terraform fmt` + `validate` (lặp qua `infra/*/`) · `trivy config` cả repo · Semgrep trên `.github` | **`trivy config`** bắt `AZU-0041 (CRITICAL)` — API server không giới hạn IP — ngay ở bản đầu của `cluster.tf` (`ai-failure-log.md` #47). **Semgrep** làm đỏ PR #94 vì không parse được 2 workflow mới (#52). **Trivy image** làm đỏ PR #94 vì CVE HIGH mới ở `sharp` — không liên quan AKS, sửa bằng PR #95 |
| `ci-aks.yml` (mới, không required) | `terraform plan` của `infra/aks` + artifact · `kubectl kustomize` + kubeconform `-strict` · shellcheck | PR #94: run `38215596574` — cả 2 job success; artifact `terraform-plan-aks` |

Artifact plan của CI ghi `Plan: 0 to add, 2 to change, 0 to destroy` — **diff giả đã biết**: CI không có
`terraform.tfvars` nên thấy `authorized_ip_ranges` đổi về `0.0.0.0/32`, kéo theo firewall rule "known after apply"
(`infra/aks/variables.tf`). IP trong artifact đã che 2 octet cuối (`104.30.x.x/32`…). Nó cũng cho thấy `id-gh-plan`
refresh được cluster (role `Cluster User`, `infra/aks/ci-permissions.tf`).

PR #94 trước khi merge: **11/11 check xanh** (9 required + 2 của `ci-aks.yml`).

## M10 — CD: merge vào `main` → tự deploy lên AKS

Tiêu chí của đề: *merge vào `main` → build → push ACR → deploy → nộp 1 lần chạy end-to-end.*

`cd-aks.yml` không build lại: nó chạy **sau khi** `CD` (App Service) xanh và dùng đúng image `vsf-be` / `vsf-fe:<sha>` đã
qua cổng Trivy. Danh tính: `id-gh-aks-deploy` (OIDC, environment `aks-deploy` chỉ nhận `main`), quyền trong cluster là
custom role chỉ có `deployments/read|write` + `replicasets/read` ở namespace `opsboard` — không `secrets`, không `pods/exec`.

### Lần chạy end-to-end (sạch)

| Thời điểm (UTC) | Sự kiện | Nguồn |
|---|---|---|
| 07:31:10 | merge PR #96 → `main` = `5b76360` | |
| 07:31 → 07:41 | `CD` run `38218203292` **success** (build, Trivy, push ACR, swap App Service) | `gh run view` |
| 07:41:18 | **`CD — AKS` run [`38219139675`](https://github.com/lam3082004/devops_vsf/actions/runs/38219139675) tự kích** (`workflow_run`) | |
| | `job build cua run CD 38218203292: success` · `provisioningState: Succeeded` | `../raw/aks-cd-run-38219139675.log` |
| | `be: …:75d25f1… -> …:5b76360…` → `successfully rolled out` → `fe` tương tự | |
| | `cho hoi tu (0s): fe [200 75d25f1…]` → **`hoi tu sau 3s`** → `lan 1…5` đều `fe [200 5b76360…] \| be [200 5b76360…] \| fe->be /health 200` | |
| 07:44:54 | **`RESULT=deployed`**, run **success** | |

Không thao tác tay nào giữa merge và lúc cluster chạy bản mới.

### Lần chạy đầu tiên — đỏ, và vì sao đó là lỗi của bước kiểm

Run [`38216996926`](https://github.com/lam3082004/devops_vsf/actions/runs/38216996926) (sau merge #94, 07:18Z): rollout `be` và
`fe` đều xong, rồi `lan 1: fe [200 771d909…] | be [200 75d25f1…]` → `kiem tra lan 1 that bai` → **rollback** → job đỏ.
`fe` trả SHA cũ vì bước kiểm chạy ngay khi `rollout status` trả về, lúc pod cũ còn trong `preStop sleep` 10 giây và vẫn
nhận request. Bản deploy **lành** bị rollback oan (`ai-failure-log.md` #54). Sửa ở PR #96: chờ hội tụ (tối đa 90 giây)
rồi mới kiểm chặt 5 lần. Hai điều lần chạy đó vẫn chứng minh được:

- danh tính giới hạn `id-gh-aks-deploy` đủ quyền `set image` / `rollout status` qua `az aks command invoke`;
- rollback tự động chạy thật: `rollback fe ve …:771d909…` rồi `rollback be ve …:771d909…`, `RESULT=rolled_back`.

### Nhánh rollback của script đã sửa

`gh workflow run cd-aks.yml -f sha=75d25f1… -f simulate_verify_failure=true` (từ `main`) → run
[`38219523331`](https://github.com/lam3082004/devops_vsf/actions/runs/38219523331): deploy `5b76360 → 75d25f1`, so với SHA sai →
`cho hoi tu (90s)…` → `khong hoi tu ve SHA mong doi sau 90s` → rollback `fe` rồi `be` về `5b76360` → `RESULT=rolled_back`,
job **failure** (đúng). Sau đó cluster: `be 5b76360`, `fe 5b76360`. Log: `../raw/aks-cd-run-38219523331.log`.

### Khi cluster tắt

`cd-aks.yml` có nhánh "cluster không tồn tại → bỏ qua, xanh". **Chưa chạy thật** (cluster bật suốt phiên) — sẽ có ở lần
merge sau `make aks-down`.

## M2 — zero-downtime

Tiêu chí của đề: *poll `/version` 1 lần/giây trong lúc deploy; 0 response non-200; version đổi A→B.*

`scripts/m2-poll.sh` (script của D18, **không sửa**) — `fe` qua load balancer, `be` qua `kubectl proxy` (API server → Service
`be`; `be` không có địa chỉ công khai), ngưỡng timeout 3 giây.

### Lần 1 — deploy, rollback, deploy lại (07:07:14 → 07:24:19Z)

[`../raw/aks-m2-2026-10-12-run1.log`](../raw/aks-m2-2026-10-12-run1.log) — 1025 tick, phủ **6 lần thay pod**:

| | request | non-200 | lỗi client / timeout | SHA |
|---|---|---|---|---|
| `be` | 1025 | **0** | **0** | `771d909 → 75d25f1` (07:20:54) `→ 771d909` (rollback, 07:21:26) `→ 75d25f1` (07:23:04) |
| `fe` | 1025 | **0** | **0** | `771d909 → 75d25f1` (07:21:08) `→ 771d909` (07:21:17) `→ 75d25f1` (07:23:11) |
| `fe-page` (tham khảo) | 1024 | 0 | 0 | — |

Request chậm nhất 2,78 giây. `be` xen kẽ SHA cũ/mới trong 2 giây lúc 07:23:02–04 (2 bản cùng phục vụ) — đúng hành vi
rolling update, không phải lỗi.

So với App Service (`../M2.md`): ở đó cũng 0 non-200 nhưng có 10 timeout client quanh lúc swap (đường WARP), mục đang chờ
mentor. Ở đây 0 timeout — nhưng **đường đo khác** (`be` đi qua API server chứ không qua Internet), nên không kết luận
"AKS tốt hơn" từ con số này.

### Lần 2 — và một gián đoạn KHÔNG do deploy (07:30:04 → ~07:49Z)

[`../raw/aks-m2-2026-10-12-run2.log`](../raw/aks-m2-2026-10-12-run2.log). Lần deploy sạch (07:42–07:44) và lần thử rollback
(07:45–07:48): **0 non-200, 0 timeout**. Nhưng log có 14 dòng lỗi, tất cả trong 12 giây, **6 phút trước** khi CD-AKS chạy:

| Thời điểm (UTC) | | |
|---|---|---|
| 07:35:52 → 07:36:00 | `be` **503** × 9 | body: `no endpoints available for service "be"` |
| 07:36:02 → 07:36:04 | `fe` timeout × 2, `fe-page` timeout × 3 | curl exit 28 |

Nguyên nhân (đọc từ event của cluster, không đoán):

1. Pod tạm của `az aks command invoke` xin **200m CPU**; node đầu chỉ còn 259m. Lần CD-AKS 07:18, pod surge của `be` (100m)
   không còn chỗ → `TriggeredScaleUp … 1->2` (07:18:58) → pod mới của `be` và `fe` rơi sang node thứ hai.
2. 07:35:47 cluster autoscaler thấy node thứ hai thừa → `Scale-down: removing node …vmss000002` → **đuổi bản duy nhất của `be`
   và của `fe`** (`deleting pod for node scale down`).
3. Pod thay thế cần ~9 giây mới Ready: trong lúc đó Service `be` không có endpoint nào.

Tức là rolling update zero-downtime, nhưng **mỗi lần deploy lại gieo một gián đoạn ~12 giây vào 15 phút sau**. Phép đo M2
"chỉ poll lúc deploy" sẽ không bao giờ thấy nó — thấy được vì poll còn chạy.

### Sửa và đo lại

`k8s/base`: `be` và `fe` chạy **2 bản** (HPA `minReplicas` 1 → 2, `fe` `replicas` 1 → 2), thêm `PodDisruptionBudget`
`minAvailable: 1` cho cả hai, và rải mềm theo node. Áp lúc 07:52Z (`make aks-deploy`), lúc đó cluster
đang có 2 node (do lần thử rollback 07:45 kéo lên) — tức đúng tình huống đã gây lỗi, lặp lại sau ~15 phút.

**Lần 3 — gỡ node sau khi sửa** (07:53:18 → 08:10:30Z, 1032 tick): [`../raw/aks-m2-2026-10-12-run3.log`](../raw/aks-m2-2026-10-12-run3.log) ·
[`../raw/aks-node-scalein-after-fix-2026-10-12.log`](../raw/aks-node-scalein-after-fix-2026-10-12.log)

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 07:52 | 2 bản mỗi service, mỗi node một bản; PDB `be`, `fe`: `allowed = 1` |
| 08:07:45 | `Scale-down: removing node …vmss000003` |
| 08:07:50 | `deleting pod for node scale down`: **một** bản `be`, **một** bản `fe`; bản thay thế được xếp lên node còn lại cùng giây |
| 08:07:52–53 | hai pod thay thế `Started` |
| 08:08:32 | node `removed` · 08:09:58 còn 1 node, 2 + 2 pod Running |

| | request | non-200 | lỗi client / timeout |
|---|---|---|---|
| `be` | 1031 | **0** | **0** |
| `fe` | 1031 | **0** | **0** |
| `fe-page` | 1031 | 0 | 0 |

Chậm nhất 2,08 giây (`fe-page`, 08:08:00). Cùng sự kiện, trước khi sửa: 14 dòng lỗi trong 12 giây.

Điều phép đo này **chưa** phủ: cả hai bản của một service cùng nằm trên node bị gỡ (PDB khi đó buộc autoscaler đuổi lần
lượt — chưa quan sát được), và node **đầu** bị gỡ thay vì node mới.

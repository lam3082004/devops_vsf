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
| 07:31:14 | merge PR #96 → `main` = `5b76360` | `gh pr view 96` (`mergedAt`) |
| 07:31 → 07:41 | `CD` run `38218203292` **success** (build, Trivy, push ACR, swap App Service) | `gh run view` |
| 07:41:18 | **`CD — AKS` run [`38219139675`](https://github.com/lam3082004/devops_vsf/actions/runs/38219139675) tự kích** (`workflow_run`) | |
| | `job build cua run CD 38218203292: success` · `provisioningState: Succeeded` | `../raw/aks-cd-run-38219139675.log` |
| | `be: …:75d25f1… -> …:5b76360…` → `successfully rolled out` → `fe` tương tự | |
| | `cho hoi tu (0s): fe [200 75d25f1…]` → **`hoi tu sau 3s`** → `lan 1…5` đều `fe [200 5b76360…] \| be [200 5b76360…] \| fe->be /health 200` | |
| 07:44:48 | **`RESULT=deployed`**, run **success** | dấu thời gian của dòng log |

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

Run [`38257441467`](https://github.com/lam3082004/devops_vsf/actions/runs/38257441467) (13:41Z, `workflow_dispatch` từ `main`,
sau `make aks-down`): đăng nhập OIDC được dù cluster không còn (quyền duy nhất sống ở bootstrap là đọc danh sách cluster),
`provisioningState: khong-co-cluster` → `Khong co cluster aks-vsf-dev (da make aks-down) — bo qua deploy AKS` → bước rollout
**skipped**, job **success**. Log: `../raw/aks-cd-run-38257441467.log`.

### Lần chạy sau khi đổi sang 2 bản — đỏ, nhưng pod lệnh vẫn tự deploy

Run [`38224419371`](https://github.com/lam3082004/devops_vsf/actions/runs/38224419371) (08:34Z, sau merge #97):
`ERROR: Operation returned an invalid status 'OK'` sau ~30 giây, job **failure**. Log + event + log của pod tạm:
`../raw/aks-cd-run-38224419371.log`.

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 08:35:07 | pod tạm `command-08fa…` (đo trực tiếp: `requests = 200m CPU / 500Mi`) `FailedScheduling: 1 Insufficient cpu` — node đầu đã xin 1791m/1900m |
| 08:35:08 | lệnh `az aks command invoke` bỏ cuộc → job đỏ |
| 08:35:19 | `TriggeredScaleUp 1->2` |
| 08:36:42 | pod tạm được xếp lên node mới và **tự chạy `aks-cd.sh`** |
| ~08:38 | log của pod: `hoi tu sau 3s` → 5/5 → **`RESULT=deployed`**; cluster chạy `280d287` |

Job báo hỏng trong khi deploy đã xảy ra. Sửa ở `cd-aks.yml` (bước *Chờ cluster có chỗ cho pod lệnh*): gọi thử `true` tới khi
chạy được rồi mới gửi lệnh rollout. Thử tay trên đúng trạng thái đã hỏng (1 node, CPU đã xin 94%), 08:54Z:
3 lần hụt → lần 4 chạy được sau 1 phút 52 giây, 4 pod tạm đều `Completed` — `../raw/aks-cd-warmup-test-2026-10-12.log`.
**Run thật bằng danh tính CD với bước này** — [`38262243519`](https://github.com/lam3082004/devops_vsf/actions/runs/38262243519),
tự kích sau `CD` `38260996070` (merge #98, `512550a`), trên cluster vừa destroy → apply lại: **success**.
Log: `../raw/aks-cd-run-38262243519.log`.

| Thời điểm (UTC) | |
|---|---|
| 14:21:48 · 14:22:21 · 14:22:54 | `lan 1/2/3: chua co cho cho pod lenh, cho node moi` (`Operation returned an invalid status 'OK'`) |
| 14:23:58 | `lan 4: pod lenh chay duoc` — 2 phút 10 giây sau lần thử đầu |
| → 14:25:10 | `be: …280d287… -> …512550a…`, `fe` tương tự → `hoi tu sau 0s` → `lan 1…5` đạt → **`RESULT=deployed`** |

Đây là lần end-to-end đầy đủ nhất của phần AKS: merge → CD App Service → CD-AKS tự chạy bằng danh tính giới hạn → chờ
có chỗ → rollout 2 bản mỗi service → kiểm → xanh, không thao tác tay.

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
| 07:35:52 → 07:36:00 | `be` **503** × 9 | body: `no endpoints available for service "be"` ([`.bodies`](../raw/aks-m2-2026-10-12-run2.log.bodies)) |
| 07:36:02 → 07:36:04 | `fe` timeout × 2, `fe-page` timeout × 3 | curl exit 28 |

Event của cluster đã lưu lại (chúng tự hết hạn sau ~1 giờ):
[`../raw/aks-node-scalein-before-fix-2026-10-12.log`](../raw/aks-node-scalein-before-fix-2026-10-12.log).

**Phần có bằng chứng trực tiếp:**

| Thời điểm (UTC) | Event |
|---|---|
| 07:18:43 | pod tạm `aks-command/command-ad96…` của `az aks command invoke` được xếp lịch và chạy |
| 07:18:46 | `FailedScheduling` pod surge `be-db965759-gf75l`: `0/1 nodes are available: 1 Insufficient cpu` |
| 07:18:58 | `TriggeredScaleUp … vmss 1->2 (max: 2)` |
| 07:35:47 | `Scale-down: removing node …vmss000002` |
| 07:35:52 | `deleting pod for node scale down`: `be-db965759-wfs2g` **và** `fe-64b5b978bc-vxrh5` — lúc đó mỗi service 1 bản |
| 07:35:54 | pod thay thế của cả hai `Pulling image` (node còn lại chưa có image của SHA đó) |

Cùng mẫu lặp lại ở lần deploy sau: 07:41:41 pod tạm → 07:41:43 `FailedScheduling` → 07:41:55 `TriggeredScaleUp`.

**Phần là suy luận, chưa đo trực tiếp:**

- *Vì sao pod surge không vừa.* Pod tạm xin **200m CPU / 500Mi** — đo được trên hai pod tạm còn tồn tại lúc 07:49Z (một
  của run 07:41), **không** đo được trên pod của run 07:18 (đã bị dọn). Node đầu khi đó còn ~259m: surge 100m một mình thì
  vừa, cộng 200m thì không. Phép tính khớp với `Insufficient cpu`, nhưng là phép tính.
- *Vì sao `be` lỗi ngay còn `fe` lỗi muộn 10 giây.* `be` được đo qua API server, vốn chỉ chuyển tới endpoint Ready → báo
  "no endpoints" ngay khi pod bị đuổi, kéo dài 9 giây gồm cả thời gian kéo image. `fe` được đo qua load balancer và vẫn
  trả 200 tới 07:36:01; timeout rơi vào 07:36:02–04, khớp với lúc pod cũ hết `preStop sleep` 10 giây mà pod mới chưa Ready
  (event `Readiness probe failed` 07:36:06 trên pod cũ). **Chưa chứng minh trực tiếp** — có thể còn phần của việc load
  balancer cập nhật khi node bị gỡ.

Tức là rolling update zero-downtime, nhưng **mỗi lần deploy lại gieo một gián đoạn vào ~15 phút sau** (`be` 9 giây, `fe` 3
giây). Phép đo M2 "chỉ poll lúc deploy" sẽ không bao giờ thấy nó — thấy được vì poll còn chạy.

### Sửa và đo lại

`k8s/base`: `be` và `fe` chạy **2 bản** (HPA `minReplicas` 1 → 2, `fe` `replicas` 1 → 2), thêm `PodDisruptionBudget`
`minAvailable: 1` cho cả hai, và rải mềm theo node. Áp lúc 07:52Z (`make aks-deploy`), lúc đó cluster
đang có 2 node (`TriggeredScaleUp` 07:41:55, do lần deploy sạch kéo lên) — tức đúng tình huống đã gây lỗi.

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

Chậm nhất 2,08 giây (`fe-page`, 08:08:00); `fe`/`fe-page` chậm 1,5–2,1 giây trong 08:07:59–08:08:04 — cùng pha với
chỗ `fe` timeout ở lần 2, tức cơ chế cũ vẫn còn dấu vết, chỉ là không vượt ngưỡng 3 giây. Cùng sự kiện, trước khi sửa:
14 dòng lỗi trong 12 giây.

**Lần 4 — gỡ node khi CẢ HAI bản cùng nằm trên node bị gỡ** (08:39:08 → 08:56:53Z, 1065 tick):
[`../raw/aks-m2-2026-10-12-run4.log`](../raw/aks-m2-2026-10-12-run4.log) ·
[`../raw/aks-node-scalein-pdb-2026-10-12.log`](../raw/aks-node-scalein-pdb-2026-10-12.log). Ca này không dàn dựng: sau lần
deploy 08:37 cả 4 pod rơi sang node mới.

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 08:51:57 | `Scale-down: removing node …vmss000004` — đang giữ 2/2 bản `be` và 2/2 bản `fe` |
| 08:52:02 | đuổi **một** bản `be` + **một** bản `fe`; bản thay thế được xếp lên node còn lại |
| 08:52:08–09 | hai bản thay thế `Started` |
| 08:52:12 | **sau đó** mới đuổi bản `be` thứ hai · 08:52:22 bản `fe` thứ hai — `PodDisruptionBudget` buộc đuổi lần lượt |
| 08:52:48 | `node … removed with drain` |

| | request | non-200 | lỗi client / timeout |
|---|---|---|---|
| `be` | 1065 | **0** | **0** |
| `fe` | 1065 | **0** | **1** — 08:52:48.800, đúng giây node bị xoá (kết nối xong sau 0,49 giây, không có byte nào về trong 3 giây) |
| `fe-page` (tham khảo) | 1065 | 0 | 4 — đều là 200 nhưng quá 3 giây: 08:41:06 (không trùng sự kiện nào), 08:53:20, 08:54:50, 08:54:51 (lúc node mới đang được thêm) |

**Kết luận sau hai lần đo.** `be`: từ 9 giây 503 xuống **0 lỗi** ở cả hai ca — PDB + 2 bản giải quyết được phần "mất bản cuối
cùng". `fe`: từ 2 timeout + 3 `fe-page` xuống **1 timeout** ở ca khó — **chưa phải 0**. Lần timeout đó trùng đúng lúc node bị
xoá chứ không trùng lúc pod bị đuổi, nên nhiều khả năng là load balancer còn gửi kết nối tới node đang biến mất
(`externalTrafficPolicy: Cluster` — node nào cũng là backend); chưa chứng minh trực tiếp và **chưa sửa** (`known-issues.md` A17).

Chưa đo: node **đầu** (đang chạy add-on) bị gỡ thay vì node mới.

# AKS — phần advanced (nhật ký)

Ngoài phạm vi `topic.md`. Kế hoạch: `docs/plans/active/aks-advanced.md` · tài liệu: `docs/aks.md` ·
bằng chứng: `evidence/advanced/`.

## 2026-10-12

**Yêu cầu của người dùng:** triển khai thêm AKS; làm ngay, song song, chỉ thêm — không đụng những thứ đã
có; đủ 4 khối (bảo mật, CD + zero-downtime, autoscale + chi phí, monitoring); evidence ghi rõ là phần
advanced; không chia lịch theo ngày; sau P0–P2 và sau P3–P5 chạy sub-agent Sonnet review.

### Khảo sát trước khi viết (az chỉ đọc)

| Đo gì | Kết quả | Quyết định |
|---|---|---|
| `az rest .../subscriptions/<id>` | `quotaId = FreeTrial_2014-09-01`, `spendingLimit = On` | cửa sổ tới 15/10; không xin tăng quota |
| `az vm list-usage -l centralindia` | `cores 4/4`, `standardDASv5Family 4/4` (2 VM `vm-obs-0x` của PoC) | không dựng ở Central India |
| `az vm list-skus -l southeastasia --all` | D2as_v5, D2s_v3, D2s_v5…: `Location: NotAvailableForSubscription` | không dựng ở Southeast Asia dù cores 0/4 |
| `az vm list-skus -l eastasia` + `list-usage` | 812 size không hạn chế, có D2as_v5; cores 0/4; public IP 0/3 | **East Asia** |
| Retail Prices API | D2as_v5 East Asia $0,119/giờ (Central India $0,0556) | chấp nhận đắt hơn để không đụng PoC |
| learn.microsoft.com (system pools, quotas-skus-regions) | B-series không làm system pool | D2as_v5, không B2s |
| AKS blog + docs app routing | managed NGINX hết hỗ trợ 11/2026; Gateway API chưa lo TLS/DNS | Service LoadBalancer, không ingress |

Bài học lặp lại của D9: quota trống **không** có nghĩa là tạo được — phải soi cả `restrictions` của SKU theo
từng region. Lần này soi trước khi viết Terraform, không mất 26 tiếng như 429 ở D9.

### P0 — baseline (03:58Z)

- `terraform -chdir=infra/app plan -lock=false` → **No changes**.
- `scripts/demo-preflight.sh --suffix jcip0s` → **0 FAIL, 1 WARN** (`.trivyignore` còn 2 ngày). Production
  `be = fe = main = 771d909`.
- Cài `kubectl` v1.36.4 + `kubelogin` v0.2.21 vào `~/.local/bin` (`az aks install-cli`). Bản mặc định là
  kubectl 1.37.1 — lệch 2 minor với cluster 1.35 nên ghim lại 1.36.4.

### P1 — Terraform

- `infra/bootstrap/aks.tf` (file mới): plan **5 to add, 0 to change, 0 to destroy** → apply
  `5 added, 0 changed, 0 destroyed` → plan lại **No changes**. State cũ sao lưu trước khi apply.
- `infra/aks` plan **27 to add, 0 to change, 0 to destroy** → apply (người dùng duyệt trong phiên).
  Log thô: `evidence/raw/aks-apply-2026-10-12.log`.

Chỗ vấp (đã vào `ai-failure-log.md`):
- `automatic_upgrade_channel = "none"` → `terraform validate` từ chối (chỉ nhận patch/rapid/stable/node-image;
  muốn "none" thì không khai).
- `authorized_ip_ranges = local.allowed_cidrs` với map rỗng = API server **mở** — `trivy config` bắt
  (`AZU-0041` CRITICAL). Sửa: rỗng thì ép `0.0.0.0/32`, sai theo hướng khoá.

### P2 — app chạy (04:36Z)

- `kubectl describe node` trước khi deploy: allocatable 1900m, pod hệ thống + add-on đã xin **1491m (78%)** →
  hạ request `be` 250m → 100m, `fe` 100m → 50m. Đo sau deploy: dùng thật `be` 31m / 53Mi, `fe` 9m / 51Mi.
- `scripts/aks-render.sh | kubectl apply -f -`: 12 object; cả hai pod Ready sau 21 giây, lần đầu, 0 restart —
  tức pull ACR (kubelet identity), mount Key Vault (workload identity), TLS tới MySQL, tạo schema đều qua.
- `make aks-verify`: lần đầu 1 FAIL do **script kiểm sai** (`GET /api/tickets` chỉ có POST) → sửa → 0 FAIL.
- `az aks command invoke` chạy được trên node 2 vCPU (~50 giây mỗi lần).

### Review Sonnet lần 1 → sửa

Prompt `docs/prompts/aks-review-1.md`. Phán quyết NO-GO có điều kiện. Sửa trước khi mở PR:
IP đầy đủ ở cuối log apply (output `allowed_cidrs`, nay `sensitive`); rollback của `aks-cd.sh` dùng `rollout undo`
(hạ cấp nhầm) → đặt lại image đã ghi nhớ; `pods/exec` của CD → kiểm bằng curl từ command pod; 3 phép kiểm của
`aks-verify.sh` có thể xanh oan. Chạy lại `aks-cd.sh` thật trong cluster: lộ thêm command pod **không có `sed`**.

### P3 — chứng minh ngược (05:00–05:15Z)

- **M5:** `-var grant_aks_keyvault_access=false` → 3 destroyed → restart `be` → pod mới `ContainerCreating`,
  event `FailedMount … 403 … ForbiddenByRbac`; pod cũ vẫn phục vụ. Xoá pod cũ → `/api/health` **503**. Trả quyền →
  pod tự lên sau ~90 giây, không restart tay → plan No changes.
- **M1:** `-var grant_aks_acr_pull=false` → đổi `fe` sang tag chưa có trên node → `ErrImagePull`, `401 Unauthorized`
  ở `/oauth2/token`. Alert `alert-vsf-aks-pod-not-starting` **Fired 05:10:27Z**. Trả quyền → về image cũ → plan No changes.
- **NetworkPolicy:** pod ở namespace `default` gọi `be:8080` → curl exit 28; gọi `fe` → 200; pod `fe` gọi `be` → 200.

Điều học được: trên Kubernetes, mất quyền **không** làm chết thứ đang chạy — rolling update giữ pod cũ, pod cũ đã có
secret và image. An toàn hơn cho người dùng, nhưng sự cố nằm im tới lần thay pod kế tiếp (known-issues A6).

### P5 — autoscale (05:18–05:30Z, 06:46–07:02Z)

- HPA: `scripts/load.sh --workers 1 --seconds 50 --duration 300` qua `kubectl proxy` → 2 pod sau 62 giây, CPU đỉnh 957%
  của request; hết tải 05:23:08, về 1 pod 05:29:42. 5/5 request 200. Node vẫn 1.
- Cluster autoscaler: pod `pause` xin 500m ở namespace tạm → `TriggeredScaleUp 1->2 (max: 2)` 06:46:59, node Ready
  06:47:44; xoá namespace 06:48:14 → `ScaleDownEmpty` 07:00:25, còn 1 node 07:01:55.
- `kubectl proxy` tới `be` đi được nhờ luật NetworkPolicy cho `konnectivity-agent` — đo được, không phải đoán.

### CVE `sharp` giữa chừng (không thuộc AKS)

CI của PR #94 đỏ ở `docker build + trivy (fe)`: GHSA-wq5f-xc86-pv6w, `sharp` 0.35.4 (optionalDependency của `next`).
PR #94 không đụng `app/` — cổng Trivy bắt đúng một advisory mới công bố. Người dùng chọn PR riêng #95 (chỉ lockfile:
`sharp` + 26 gói `@img/*`), 9/9 check xanh, merge 06:48Z, CD success. Không có cổng này thì lỗi sẽ lộ ra ở lần CD
đầu tiên của buổi demo.

### P4 — CI/CD (07:08–07:24Z)

- PR #94: 11/11 check xanh (9 required + 2 của `ci-aks.yml`) sau hai vòng sửa: Semgrep không parse được workflow mới
  (#52), rồi cổng Trivy bắt CVE `sharp` (PR #95).
- Merge #94 lúc 07:08:28Z → `CD` `38216113229` success (swap App Service, production `75d25f1`) → **`CD — AKS` tự chạy**
  (`workflow_run`, run `38216996926`): job build của CD = success, cluster `Succeeded`, đăng nhập OIDC bằng
  `id-gh-aks-deploy`, `set image` + `rollout status` chạy được với custom role (không `pods/exec`, không `secrets`).
- Run đó **đỏ và tự rollback**: bước kiểm của tôi trúng pod `fe` cũ đang tắt dần (#54). Rollback đặt lại đúng image cũ,
  `fe` trước `be`. Sửa `aks-cd.sh` (chờ hội tụ) → chạy tay bằng rollout thật: hội tụ sau 3 giây, `RESULT=deployed`.
- `scripts/m2-poll.sh` (không sửa) chạy 07:07:14 → 07:24:19Z, 1025 tick, qua **6 lần thay pod** (deploy, rollback, deploy
  lại): `be` 0 non-200 / 0 lỗi client, `fe` 0 / 0, `fe-page` 0 / 0. Chậm nhất 2,78 giây (ngưỡng 3 giây).
- `aks-m6-check.yml` lần đầu: job chết vì `bash -e` + curl timeout (#53) — nhưng chính dòng đó cho thấy runner
  **không** tới được `fe`. Sửa, chờ vào `main` để đo lại cả hai bề mặt.

### P4 tiếp — CD-AKS xanh, và gián đoạn khi gỡ node (07:31–07:55Z)

- Merge #96 07:31:10Z → `CD` `38218203292` success → `CD — AKS` `38219139675` **success**: hội tụ sau 3 giây, 5/5, `RESULT=deployed`.
- `simulate_verify_failure` (run `38219523331`): không hội tụ sau 90 giây → rollback → cluster về `5b76360`. Đúng.
- `aks-m6-check.yml` sau khi sửa (run `38218242391`): runner `48.217.x.x` → `fe` 000, API server 000; cùng lúc máy trong
  whitelist → 200 và 401.
- **Phát hiện:** `m2-poll` lần 2 có 14 dòng lỗi lúc 07:35:52–07:36:04, không trùng lần deploy nào. Event: `Scale-down:
  removing node vmss000002` 07:35:47 → `deleting pod for node scale down` cho cả `be` lẫn `fe` (mỗi cái 1 bản, cùng nằm
  trên node đó). Node đó sinh ra lúc 07:18:58 vì pod surge của `be` không vừa cạnh pod tạm 200m của `command invoke`.
- Sửa 07:52Z: 2 bản + PDB + rải mềm; HPA min 2. `make aks-deploy` → 2 bản mỗi service, mỗi node một bản, PDB `allowed=1`.

### P6 — monitoring (07:10–07:30Z)

- Workspace riêng có đủ `Perf`, `ContainerLogV2`, `KubePodInventory`, `AppRequests` (`be-aks`/`fe-aks`), `AppExceptions`.
- `scripts/boom.sh` 480 request/480 giây qua `kubectl proxy` → `alert-vsf-aks-5xx-rate` **Fired 07:28:35Z** (17% lỗi của `be-aks`).
- Truy vết: `trace_id` của một dòng `/boom` → cùng giá trị ở `ContainerLogV2`, `AppRequests.OperationId`, `AppExceptions`.
- KQL: `last` là từ khoá — đặt tên cột `latest`.

### Review Sonnet lần 2 → sửa (08:12–08:25Z)

Prompt `docs/prompts/aks-review-2.md`, phán quyết GO có điều kiện. Ba điều học được:

- **Event của cluster là bằng chứng có hạn dùng (~1 giờ).** Lúc reviewer nhắc thì event cũ nhất còn lại là 07:18:43 — đúng
  dòng đầu của chuỗi nguyên nhân. Chậm vài phút nữa là mất. Lưu ngay khi thấy, đừng để tới lúc viết tài liệu.
- **"Đo được" và "tính ra" phải viết khác nhau.** Request 200m của pod tạm là đo (trên pod của run 07:41), nhưng "nên pod
  surge không vừa" là phép tính; và lý do `fe` timeout muộn hơn `be` 10 giây là suy luận khớp thời điểm, chưa chứng minh.
- **Một lần đo qua được không phải là "đã sửa".** Lần 3 qua vì mỗi node tình cờ một bản; PDB chưa phải làm gì.

### Sau #97: CD-AKS gãy vì chính bản sửa, và ca PDB thật (08:24–08:58Z)

- Merge #97 08:24Z → `CD` xanh → `CD — AKS` `38224419371` đỏ sau 30 giây: `Operation returned an invalid status 'OK'`.
  Pod tạm `command-08fa…` (đo trực tiếp: 200m / 500Mi) `FailedScheduling: Insufficient cpu` → `TriggeredScaleUp` →
  08:36:42 xếp được lên node mới → **tự chạy `aks-cd.sh`** → 08:38 `RESULT=deployed` (`280d287`). Job đỏ, deploy thành công.
- Cả 4 pod mới rơi sang node thứ hai → 08:51:57 autoscaler gỡ node đó: PDB đuổi lần lượt (08:52:02 rồi 08:52:12 / 08:52:22).
  `be` 0 lỗi; `fe` 1 timeout lúc 08:52:48 (đúng giây node bị xoá). Không dàn dựng — ca này tự xảy ra.
- Sửa `cd-aks.yml`: bước chờ có chỗ. Thử tay trên cluster 1 node, CPU đã xin 94%: 3 lần hụt, lần 4 được (1 phút 52 giây);
  4 pod tạm `true` đều Completed.
- Bài học của cả buổi chiều: mỗi lần "sửa xong" là một lần cấu hình mới chưa ai chạy hết các đường — #54, #55, #56 đều lộ ra
  ở lần chạy thật **kế tiếp**, không phải ở lần thử ngay sau khi sửa.

### P7 — destroy → apply (08:59 → 13:56Z)

- `plan -destroy`: 27 to destroy, không resource nào của `infra/app`. `destroy` 19 phút 54 giây. State 0, hai RG không còn.
  (Cluster tắt từ 09:19Z tới 13:43Z.)
- `gh workflow run cd-aks.yml` lúc cluster tắt → run `38257441467`: `khong-co-cluster` → bỏ qua, xanh.
- `apply` từ rỗng: 24 created rồi 2 lỗi 400 (alert 5xx, data collection rule). Workspace `createdDate` = 04:24Z ⇒ bị **khôi
  phục từ xoá mềm**. `apply` lần 2: 3 added. Sửa: `permanently_delete_on_destroy = true` — chưa kiểm lại.
- `make aks-deploy`: 14 object, 2/2 + 2/2 sau 53 giây (cluster mới, IP outbound mới, identity mới — `aks-render.sh` đọc lại
  hết từ `terraform output`). `make aks-verify`: 0 FAIL.

### Kết thúc (14:10 → 14:55Z)

- Merge #98 14:10:34Z → `CD` `38260996070` success (production `512550a`) → `CD — AKS` `38262243519` **success**: bước chờ có chỗ
  hụt 3 lần, lần 4 được (14:23:58), rollout `be` → `fe`, hội tụ 0 giây, 5/5, `RESULT=deployed`.
- `make aks-verify` cuối: một lần FAIL thoáng qua (kubectl đọc Service hụt, script in "KHÔNG khớp (0 dải)") → chạy lại 0 FAIL;
  sửa script để phân biệt "không đọc được" với "không khớp".
- `make aks-down`: 27 destroyed (21 phút 57 giây). Không sót: state 0, hai RG không còn, MySQL chỉ còn `appdb`, không còn rule
  `aks-outbound`, không còn secret, 0 workspace xoá mềm, 0/4 vCPU East Asia. `infra/app` No changes, preflight 0 FAIL.
- Hôm nay App Service swap 5 lần vì phần AKS (#95, #94, #96, #97, #98) — cả 5 run `CD` đều success.

### Ảnh chụp bù (15:25 → 16:05Z)

Người dùng nhắc: làm AKS mà không chụp ảnh nào. Đúng — cả ngày chỉ lưu log thô. Chụp bù bằng Claude in Chrome:

- GitHub (8 ảnh): các run `CD — AKS`, `aks-m6-check`, PR #94 — là ảnh của đúng các lần chạy ban ngày.
- Portal (8 ảnh): ban đầu extension bị từ chối trên `portal.azure.com`; người dùng bật quyền. Chụp toàn trang làm treo tab
  (CDP timeout) → chụp theo vùng (`zoom`) thì được. Mỗi tab mới phải chọn lại tài khoản; chọn tài khoản trường (khớp `az account show`),
  không dùng tài khoản công ty.
- Ứng dụng (4 ảnh): Chrome không mở `http://<IP>` → `kubectl port-forward` rồi chụp `localhost:3000`.
- Phải dựng cluster lần ba để có trang Portal; nhân tiện kiểm xong A20 (`apply` một lần, workspace mới thật). Tắt lại sau khi chụp.
- Không chụp lại được: các khoảnh khắc lỗi/co giãn ban ngày. Lần sau chụp **ngay lúc xảy ra** — nhất là lúc đỏ.

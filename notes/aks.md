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

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

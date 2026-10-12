# Evidence — phần ADVANCED: AKS

> **PHẦN ADVANCED — ngoài phạm vi `topic.md` (M1–M11, S1–S3).** Bài chính được nộp trên App Service, bằng
> chứng của nó là `evidence/M1.md` … `M11.md` và không đổi. Thư mục này là phần **làm thêm** từ 2026-10-12:
> cùng app OpsBoard chạy trên AKS, song song, chỉ thêm. Không file nào ở đây thay cho bằng chứng của đề bài.

Kế hoạch: [`docs/plans/active/aks-advanced.md`](../../docs/plans/active/aks-advanced.md) ·
tài liệu: [`docs/aks.md`](../../docs/aks.md) · nhật ký: [`notes/aks.md`](../../notes/aks.md).

Mỗi file lấy **cùng tiêu chí chứng minh** của must-have tương ứng rồi làm lại trên AKS. Tên `aks-mN` chỉ để
đối chiếu, không phải mã yêu cầu mới của đề.

| File | Tương đương | Trạng thái |
|---|---|---|
| [`aks-m8.md`](aks-m8.md) | M8 — Terraform toàn bộ hạ tầng | xem file |
| [`aks-m1.md`](aks-m1.md) | M1 — pull image bằng managed identity | xem file |
| [`aks-m3.md`](aks-m3.md) | M3 — MySQL + firewall theo outbound IP | xem file |
| [`aks-m4-m5.md`](aks-m4-m5.md) | M4, M5 — managed identity + Key Vault, chứng minh ngược | xem file |
| [`aks-m6.md`](aks-m6.md) | M6 — IP whitelist | xem file |
| [`aks-m9-m10-m2.md`](aks-m9-m10-m2.md) | M9, M10, M2 — CI, CD, zero-downtime | xem file |
| [`aks-m7.md`](aks-m7.md) | M7 — autoscale + chi phí | xem file |
| [`aks-m11.md`](aks-m11.md) | M11 — monitoring | xem file |

Log thô: `evidence/raw/aks-*`. Mọi địa chỉ IPv4 trong log đã che 2 octet cuối.

Chốt chặn "không đụng môi trường cũ" (chạy lại sau mỗi pha): `evidence/raw/aks-guard-*.log` —
`terraform -chdir=infra/app plan` phải ra **No changes**, `scripts/demo-preflight.sh` phải **0 FAIL**.

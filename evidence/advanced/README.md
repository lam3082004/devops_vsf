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
| [`aks-m8.md`](aks-m8.md) | M8 — Terraform toàn bộ hạ tầng | dựng từ rỗng **đạt**; destroy → apply lại: chưa làm (bước cuối) |
| [`aks-m1.md`](aks-m1.md) | M1 — pull image bằng managed identity | **đạt**, có chứng minh ngược + alert Fired |
| [`aks-m3.md`](aks-m3.md) | M3 — MySQL + firewall theo outbound IP | **đạt** |
| [`aks-m4-m5.md`](aks-m4-m5.md) | M4, M5 — managed identity + Key Vault, chứng minh ngược | **đạt** |
| [`aks-m6.md`](aks-m6.md) | M6 — IP whitelist | **đạt**: trong whitelist → 200; runner GitHub → `fe` và API server đều không kết nối được; `be` bị chặn trong cluster |
| [`aks-m7.md`](aks-m7.md) | M7 — autoscale + chi phí | autoscale + right sizing **đạt**; chi phí mới là giá niêm yết, **chưa có Actual cost** |
| [`aks-m9-m10-m2.md`](aks-m9-m10-m2.md) | M9, M10, M2 — CI, CD, zero-downtime | CI, CD end-to-end, zero-downtime **lúc rollout**: **đạt**. Gián đoạn khi gỡ node: `be` hết lỗi sau khi sửa (2 lần đo, gồm ca 2 bản cùng node); `fe` **còn 1 timeout** lúc node bị xoá — chưa sửa. CD-AKS cần bước chờ cluster có chỗ (sửa sau run đỏ `38224419371`) |
| [`aks-m11.md`](aks-m11.md) | M11 — monitoring | log, alert (2 lần Fired thật), truy vết **đạt**; **chưa có** ảnh Workbook và ảnh email |

Log thô: `evidence/raw/aks-*`. Mọi địa chỉ IPv4 trong log đã che 2 octet cuối.

Chốt chặn "không đụng môi trường cũ" (chạy lại sau mỗi pha): `evidence/raw/aks-guard-*.log` —
`terraform -chdir=infra/app plan` phải ra **No changes**, `scripts/demo-preflight.sh` phải **0 FAIL**.

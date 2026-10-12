# AKS · tương đương M8 — Terraform toàn bộ hạ tầng

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M8 của đề bài là [`../M8.md`](../M8.md).

Ngày: 2026-10-12 · nhánh `feat/aks-infra` · root module `infra/aks`, state `aks.tfstate`
Môi trường nền: `rg-vsf-dev` suffix `jcip0s` (đang bật) · cluster `aks-vsf-dev` ở `rg-vsf-aks`, East Asia

## Lần dựng đầu

| Bước | Kết quả | Nguồn |
|---|---|---|
| `infra/bootstrap` plan → apply (`aks.tf`, file mới) | **5 to add, 0 to change, 0 to destroy** → `5 added` → plan lại **No changes** | chạy trong phiên; state cũ sao lưu trước apply |
| `infra/aks` plan | **27 to add, 0 to change, 0 to destroy** | người dùng duyệt apply trong phiên |
| `infra/aks` apply | **`Apply complete! Resources: 27 added, 0 changed, 0 destroyed.`** — 04:23:24Z → 04:33:38Z (**10 phút 14 giây**), một pha | [`../raw/aks-apply-2026-10-12.log`](../raw/aks-apply-2026-10-12.log) |
| `infra/aks` plan lần hai | **No changes** | chạy ngay sau apply |
| Áp manifest (`scripts/aks-render.sh \| kubectl apply -f -`) | 12 object; `be` và `fe` **Ready sau 21 giây**, 0 restart | `notes/aks.md` |
| Bảng kiểm `make aks-verify` | **0 FAIL, 0 WARN** (19 phép kiểm) | [`../raw/aks-verify-2026-10-12.log`](../raw/aks-verify-2026-10-12.log) |

Không thao tác tay nào trên Portal. Khác `make up` của bài chính (3 pha): một pha là đủ, vì không có
`for_each` nào dùng giá trị "known after apply" — IP outbound của cluster chỉ là một thuộc tính của **một**
firewall rule, không phải khoá của `for_each` (`infra/aks/db.tf`).

## Môi trường cũ không bị đụng

| Lúc | `terraform -chdir=infra/app plan` | `scripts/demo-preflight.sh` |
|---|---|---|
| Trước khi tạo gì (03:58Z) | No changes | 0 FAIL, 1 WARN (`.trivyignore` còn 2 ngày) |
| Sau P2 (04:38Z) | **No changes** | **0 FAIL, 1 WARN** (cùng WARN) — [`../raw/aks-guard-after-p2-2026-10-12.log`](../raw/aks-guard-after-p2-2026-10-12.log) |
| Sau P5 và sau PR #95 (07:03Z) | *không chạy lại ở mốc này* | **0 FAIL, 1 WARN** — [`../raw/aks-guard-after-p5-2026-10-12.log`](../raw/aks-guard-after-p5-2026-10-12.log) |
| Sau P6 (08:12Z) | **No changes** | **0 FAIL, 1 WARN**, production `5b76360`, không alert nào của bài chính Fired — [`../raw/aks-guard-after-p6-2026-10-12.log`](../raw/aks-guard-after-p6-2026-10-12.log) |
| Sau P7 — destroy → apply của `infra/aks` (13:57Z) | **No changes** | **0 FAIL, 1 WARN**, production `280d287` — [`../raw/aks-guard-after-p7-2026-10-12.log`](../raw/aks-guard-after-p7-2026-10-12.log) |

Thứ root này thêm lên resource của `infra/app` (đều là resource con mới, nằm ở `aks.tfstate`): 1 role
`AcrPull` trên ACR · 1 database `appdb_aks` + 1 firewall rule `aks-outbound` trên MySQL · 1 secret
`aks-appinsights-connection-string` + 3 role `Key Vault Secrets User` ở scope secret trên Key Vault.

## Destroy → apply lại (12/10, 08:59 → 13:56Z)

Tiêu chí của đề cho M8: *`terraform destroy` → `apply` ra môi trường chạy được, **không một thao tác tay**.*
Kết quả trên AKS: **đạt một phần** — môi trường dựng lại chạy được, nhưng `apply` phải chạy **hai lần**.

| Bước | Kết quả | Nguồn |
|---|---|---|
| `plan -destroy` | **0 to add, 0 to change, 27 to destroy** — đúng 27 resource của `infra/aks`, không resource nào của `infra/app` | chạy trong phiên |
| `destroy` | **`27 destroyed`** — 08:59:26 → 09:19:20Z (**19 phút 54 giây**) | [`../raw/aks-destroy-2026-10-12.log`](../raw/aks-destroy-2026-10-12.log) |
| Sau destroy | `terraform state list`: 0 · `make aks-check-empty`: `rg-vsf-aks` và `rg-vsf-aks-nodes` **không tồn tại** | chạy 13:40Z |
| CD-AKS lúc cluster tắt | run `38257441467`: bỏ qua, **xanh** | `aks-m9-m10-m2.md` |
| `apply` lần 1 (từ rỗng, plan 27 to add) | **24 created, 2 lỗi** — 13:42:35 → 13:52:08Z (9 phút 33 giây) | [`../raw/aks-reapply-2026-10-12.log`](../raw/aks-reapply-2026-10-12.log) |
| `apply` lần 2 (không sửa code, plan 3 to add) | **`3 added`** — 13:53:21 → 13:53:59Z | cùng file |
| `plan` sau đó | **No changes** | chạy trong phiên |
| `make aks-deploy` | 14 object; `be` 2/2, `fe` 2/2 sau 53 giây | `notes/aks.md` |
| `make aks-verify` | **0 FAIL, 0 WARN** — IP outbound mới, IP load balancer mới, identity mới, tất cả tự khớp qua `terraform output` | [`../raw/aks-verify-2026-10-12-after-reapply.log`](../raw/aks-verify-2026-10-12-after-reapply.log) |

### Hai lỗi của lần apply đầu — và vì sao lần dựng đầu tiên không gặp

```
alert-vsf-aks-5xx-rate:  400 BadRequest: The workspace could not be found
dcr-aks-vsf-dev-ci:      400 InvalidPayload: Data collection rule is invalid
```

Workspace `log-vsf-aks-jcip0s` vừa được "tạo" lúc 13:43Z nhưng `az monitor log-analytics workspace show` trả
`createdDate = 2026-10-12T04:24:07Z` — ngày tạo của bản **đã bị destroy**. Log Analytics xoá mềm 14 ngày, và tạo lại cùng tên
trong thời gian đó là **khôi phục** workspace cũ; trong lúc khôi phục, resource tạo ngay sau nó chưa thấy nó. Lần dựng đầu
(04:23Z) workspace là mới thật nên alert tạo ngay sau 9 giây vẫn được.

Sửa: `infra/aks/versions.tf` — `log_analytics_workspace { permanently_delete_on_destroy = true }`, để destroy xoá hẳn.
**Bản sửa chưa được kiểm bằng một vòng destroy → apply nữa**; có hiệu lực từ lần `make aks-down` kế tiếp.

Đây chính là giá trị của M8: `plan` No changes và một lần apply sạch **không** chứng minh được rằng dựng lại được.

## Tắt cuối phiên (14:29 → 14:52Z)

| Bước | Kết quả | Nguồn |
|---|---|---|
| `plan -destroy` | **27 to destroy** | chạy trong phiên |
| `destroy` | **`27 destroyed`** — 14:29:42 → 14:51:39Z (21 phút 57 giây) | [`../raw/aks-destroy-final-2026-10-12.log`](../raw/aks-destroy-final-2026-10-12.log) |
| Còn sót gì | state 0 · `rg-vsf-aks`, `rg-vsf-aks-nodes` không tồn tại · 0 cluster · MySQL chỉ còn database `appdb`, 0 rule `aks-outbound` · 0 secret `aks-appinsights-…` (kể cả xoá mềm) · vCPU East Asia 0/4 | [`../raw/aks-teardown-check-2026-10-12.log`](../raw/aks-teardown-check-2026-10-12.log) |
| Workspace | **0** workspace `log-vsf-aks-*` trong danh sách xoá mềm — `permanently_delete_on_destroy` có hiệu lực ở lần destroy này | cùng file |
| Môi trường cũ | `infra/app` plan **No changes** · preflight **0 FAIL** · production `512550a` | cùng file |

Nửa còn lại của bản sửa A20 (lần `apply` kế tiếp tạo workspace **mới** và chạy một lần là xong) chỉ kiểm được ở lần
`make aks-up` tới.

## Lần dựng thứ ba — `apply` một lần là xong (15:26 → 15:36Z)

Dựng lại để chụp ảnh, đồng thời là phép kiểm nửa sau của bản sửa A20.

| Bước | Kết quả | Nguồn |
|---|---|---|
| `plan` | 27 to add, 0 to change, 0 to destroy | chạy trong phiên |
| `apply` | **`27 added, 0 changed, 0 destroyed` — một lần**, 15:26:51 → 15:36:16Z (9 phút 25 giây) | [`../raw/aks-reapply-once-2026-10-12.log`](../raw/aks-reapply-once-2026-10-12.log) |
| Workspace | `createdDate = 2026-10-12T15:27:37Z` — **mới thật**, không phải bản khôi phục (lần trước: 04:24Z) | `az monitor log-analytics workspace show` |
| `make aks-deploy` + `make aks-verify` | `be` 2/2, `fe` 2/2 · **0 FAIL** | chạy trong phiên |
| Ảnh Portal của cluster này | [`../advanced/screenshots/`](screenshots/README.md) | |

Vậy với `permanently_delete_on_destroy = true`, vòng destroy → apply của `infra/aks` chạy **không thao tác tay và không
phải chạy lại** — tiêu chí M8 đạt ở lần này. Cluster được tắt sau khi chụp (15:55 → 16:15Z, `27 destroyed`), rồi dựng
lại lần bốn và **để bật** theo quyết định của người dùng (`docs/plans/active/aks-advanced.md`, Decision P).

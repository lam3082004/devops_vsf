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

Thứ root này thêm lên resource của `infra/app` (đều là resource con mới, nằm ở `aks.tfstate`): 1 role
`AcrPull` trên ACR · 1 database `appdb_aks` + 1 firewall rule `aks-outbound` trên MySQL · 1 secret
`aks-appinsights-connection-string` + 3 role `Key Vault Secrets User` ở scope secret trên Key Vault.

## Destroy → apply lại

Chưa làm — làm ở bước cuối (P7) để không mất cluster giữa chừng. Kết quả ghi ở mục này khi có.

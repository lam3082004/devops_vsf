# AKS · tương đương M6 — chỉ truy cập được từ IP trong whitelist

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M6 của đề bài là [`../M6.md`](../M6.md).

Ngày: 2026-10-12 · log thô: [`../raw/aks-verify-2026-10-12.log`](../raw/aks-verify-2026-10-12.log) ·
[`../raw/aks-networkpolicy-2026-10-12.log`](../raw/aks-networkpolicy-2026-10-12.log)

Tiêu chí của đề: *`curl` từ IP cho phép → 200; từ IP khác → bị chặn.*

## Bề mặt nào, khoá bằng gì

App Service của bài chính có 8 bề mặt (site + Kudu × production/staging × `be`/`fe`), tất cả công khai và cùng khoá bằng
`ip_restriction`. AKS có ít bề mặt công khai hơn, và mỗi cái một cơ chế:

| Bề mặt | Công khai? | Khoá bằng | Nguồn danh sách IP |
|---|---|---|---|
| `fe` (Service LoadBalancer :80) | có | `loadBalancerSourceRanges` → Azure dựng thành luật NSG | `var.allowed_ips` của `infra/aks` → `scripts/aks-render.sh` |
| API server (vai trò của Kudu/SCM) | có | `authorized_ip_ranges` + tắt local account + Azure RBAC | `var.allowed_ips` của `infra/aks` |
| `be` | **không** — ClusterIP | NetworkPolicy `be-ingress`: chỉ `fe`, API server, command pod của CD | `k8s/base/networkpolicy.yaml` |

Cùng một biến `allowed_ips` cho cả hai bề mặt công khai, khai trong `terraform.tfvars` ngoài git — đúng bài học D13
("khoá site chính mà quên Kudu thì coi như chưa khoá"). Quên tfvars: API server ép về `0.0.0.0/32` (khoá hết),
`aks-render.sh` từ chối render Service — sai theo hướng **đóng**.

## Từ IP trong whitelist → 200

`make aks-verify` (máy làm việc, IP trong `allowed_ips`):

```
OK    API server giới hạn 3 dải IP
OK    Service fe giới hạn 3 dải IP, khớp allowed_ips của infra/aks
OK    be là ClusterIP (không có IP công khai)
OK    fe /api/version = 200, SHA 771d909 khớp tag image (LB 4.192.x.x)
OK    fe /api/health = 200 (fe → be → MySQL thông)
```

## `be` không vào được từ nơi khác trong cluster

| Gọi từ | Tới | Kết quả |
|---|---|---|
| pod lạ ở namespace `default` | `be.opsboard.svc:8080/version` | **`HTTP 000 curl_exit=28`** (timeout — Cilium rớt gói) |
| pod lạ ở namespace `default` | `fe.opsboard.svc/api/version` | 200 (`fe` không có NetworkPolicy — `known-issues.md` A7) |
| pod `fe` | `be:8080/version` | **200** `{"sha":"771d909…"}` |

## Từ IP ngoài whitelist → bị chặn

**Chưa đo.** Phép đo dùng `aks-m6-check.yml` (runner GitHub gọi `fe` và API server, mong đợi không kết nối được), mà
workflow chỉ chạy được sau khi file nằm trên `main`. Kết quả ghi vào mục này bằng PR kế tiếp.

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

Workflow [`aks-m6-check.yml`](../../.github/workflows/aks-m6-check.yml) — runner GitHub, không secret, không OIDC — gọi hai bề
mặt công khai và mong đợi **không kết nối được**. Cùng thời điểm, máy trong whitelist gọi đúng hai địa chỉ đó làm ca đối
chứng (để "không kết nối được" không thể là do cluster đang tắt). Log thô: [`../raw/aks-m6-2026-10-12.log`](../raw/aks-m6-2026-10-12.log).

Run [`38218242391`](https://github.com/lam3082004/devops_vsf/actions/runs/38218242391) — **success**:

| Thời điểm (UTC) | Gọi từ | Bề mặt | Kết quả |
|---|---|---|---|
| 07:31:42 | máy trong whitelist | `http://<LB>/api/version` | **200** |
| 07:31:43 | máy trong whitelist | `https://<api-fqdn>/version` | **401** — tới được API server, chưa xác thực |
| 07:32:01 | runner `48.217.x.x` | `http://<LB>/api/version` | **000** — curl hết giờ 15 giây (đạt) |
| 07:32:16 | runner `48.217.x.x` | `https://<api-fqdn>/version` | **000** — curl hết giờ 15 giây (đạt) |

Khác App Service ở **kiểu** bị chặn: `ip_restriction` trả **403** (có một máy chủ trả lời "không"); ở đây gói bị rớt ở tầng
mạng nên không có ai trả lời — `000`, không phải 403. Vì thế phép đo phải có ca đối chứng.

Lần chạy đầu của workflow (run `38216155724`, 07:09Z) **đỏ oan**: bước `run` chạy bằng `bash -e`, curl hết giờ (exit 28) làm
job chết ở đúng kết quả mong đợi (`ai-failure-log.md` #53). Sửa ở PR #96, đo lại ra bảng trên.

## Giới hạn

- Whitelist hiện có **3 dải**, trong đó hai dải là dải tài liệu RFC 5737 không route được (chép nguyên từ
  `infra/app/terraform.tfvars`, `known-issues.md` #19) — thực tế chỉ một IP vào được.
- IP đó là IP thoát của mạng đang dùng; đổi mạng là mất quyền vào cả `fe` lẫn API server, phải sửa tfvars rồi
  `make aks-up` (ARM vẫn vào được nên không tự khoá mình vĩnh viễn).
- `fe` chạy **HTTP** — `known-issues.md` A1.

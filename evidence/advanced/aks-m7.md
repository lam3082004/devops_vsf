# AKS · tương đương M7 — autoscale (tối đa 2), right sizing, chi phí

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M7 của đề bài là [`../M7.md`](../M7.md) và
> [`../../cost-report.md`](../../cost-report.md).

Ngày: 2026-10-12 · cluster `aks-vsf-dev`, East Asia, 1 node pool `Standard_D2as_v5` (2 vCPU / 8 GB)
Log thô: [`../raw/aks-load-2026-10-12.log`](../raw/aks-load-2026-10-12.log) ·
[`../raw/aks-watch-2026-10-12.log`](../raw/aks-watch-2026-10-12.log) ·
[`../raw/aks-node-autoscale-2026-10-12.log`](../raw/aks-node-autoscale-2026-10-12.log)

App Service có **một** tầng autoscale (số instance của Plan). AKS có **hai**, cả hai đều giới hạn ở 2 theo luật project:

| Tầng | Cấu hình | Nơi khai | Tối đa |
|---|---|---|---|
| Pod — HPA `be` | CPU > 70% **của request** (100m) → thêm pod; ổn định 5 phút rồi mới giảm. **Lúc đo mục 1: min 1. Từ 07:52Z 12/10: min 2** (mục 5) | `k8s/base/hpa.yaml` | **2 pod** |
| Node — cluster autoscaler | có pod `Pending` vì thiếu chỗ → thêm node; node thừa ~10 phút → gỡ | `infra/aks/cluster.tf` (`var.node_max_count`, validation `<= 2`) | **2 node** |

`make aks-verify` kiểm cả hai con số trên cluster thật.

## 1. HPA: 1 → 2 → 1 pod

Tải: `scripts/load.sh --workers 1 --seconds 50 --duration 300` vào `be` qua `kubectl proxy` (script của D19, không sửa).
Một worker là đủ: mỗi request `/load` đốt trọn một nhân, tức 1000% của request 100m.

| Thời điểm (UTC) | Sự kiện | Nguồn |
|---|---|---|
| 05:18:49 | nền: 1 pod, CPU **2%** | watch |
| 05:18:56 | bắt đầu tải | load |
| **05:19:58** | **2 pod Ready**, CPU 493% — **62 giây** sau khi tải bắt đầu | watch (mẫu trước đó, 05:19:34, còn 1 pod) |
| 05:21:00 | CPU đỉnh 957% (trung bình hai pod) | watch |
| 05:23:08 | hết tải: **5/5 request 200**, mỗi request 50,2 giây | load |
| **05:29:42** | **về 1 pod** — 6 phút 34 giây sau khi hết tải (cửa sổ ổn định 5 phút của HPA) | watch |

Suốt phép thử: `fe` 1/1 Ready, 0 pod Pending, **1 node** — pod thứ hai vừa node đầu, không kéo thêm máy.

So với App Service (D19, cùng kiểu tải): 1→2 instance sau **6 phút 35 giây**, 2→1 sau 10 phút 43 giây. Thêm một pod
trên node sẵn có nhanh hơn thêm một instance của Plan khoảng 6 lần — vì không phải cấp máy mới.

## 2. Cluster autoscaler: 1 → 2 → 1 node

Ở mức tối đa 2 pod, app **không** tự làm đầy node (mục 3), nên chứng minh bằng một phép thử riêng: một pod giữ chỗ
(`pause`, request 500m CPU) ở namespace tạm `aks-autoscale-test`, không đụng namespace của app. Node đầu chỉ còn 259m trống.

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 06:46:42 | tạo Deployment `balloon` |
| 06:46:46 | `FailedScheduling: 0/1 nodes are available: 1 Insufficient cpu` |
| **06:46:59** | **`TriggeredScaleUp: … vmss 1->2 (max: 2)`** |
| 06:47:23 | node thứ hai xuất hiện; **06:47:44 Ready** — 45 giây sau lệnh scale-up |
| 06:48:12 | pod `balloon` Running trên `vmss000001` |
| 06:48:14 | xoá namespace tạm → node thứ hai thừa |
| **07:00:25** | **`ScaleDownEmpty: removing empty node "…vmss000001"`** — 12 phút 11 giây sau khi node hết việc; 07:00:40 `removed` |
| 07:01:55 | `kubectl get nodes`: **1 node** |

Node thứ hai sống ~14 phút ≈ $0,03 theo giá niêm yết.

## 3. Right sizing — đo rồi mới chốt

| Đo trên node (`kubectl describe node`, `kubectl top`) | Giá trị |
|---|---|
| CPU allocatable | 1900m (2 vCPU trừ phần giữ cho kubelet/hệ thống) |
| Pod hệ thống + add-on **đã xin** trước khi có app | **1491m (78%)** — Cilium, CoreDNS ×2, metrics-server ×2, konnectivity ×2, workload identity webhook ×2, Key Vault CSI, Container Insights, CSI disk/file |
| Còn cho app | ~400m |
| `be` dùng thật lúc rỗi | 31m CPU · 53 Mi |
| `fe` dùng thật lúc rỗi | 9m CPU · 51 Mi |
| CPU thật của cả node lúc rỗi | 253m (13%) · memory 1823 Mi (31%) |

Kết luận:

- **Request:** `be` 100m, `fe` 50m (kế hoạch ban đầu 250m/100m, viết khi chưa đo — `ai-failure-log.md` #49). Với
  100m: pod surge lúc rollout và pod thứ hai của HPA đều vừa node đầu.
- **Size node:** giữ `Standard_D2as_v5`. CPU *dùng thật* chỉ 13%, nhưng CPU *request* đã 86% — thứ chật là phần giữ chỗ
  của add-on, không phải tải. Nhỏ hơn 2 vCPU thì add-on không vừa; B-series rẻ hơn nhưng AKS không cho làm system pool.
- **Số node:** 1 là đủ cho app này ở mức tối đa 2 pod; node thứ hai chỉ xuất hiện khi có thứ khác xin chỗ.

## 4. Chi phí

Giá niêm yết (Retail Prices API, East Asia, 12/10) — **không phải Actual cost**: Cost analysis trễ 8–24 giờ, cluster mới
dựng hôm nay nên chưa có số thật. Bảng đầy đủ và so sánh với App Service: [`../../cost-report.md`](../../cost-report.md)
mục "Advanced — AKS".

| Thành phần | Giá | 1 node | 2 node |
|---|---|---|---|
| Control plane (tier Free) | $0 | $0 | $0 |
| Node `Standard_D2as_v5` | $0,119/giờ | $0,119 | $0,238 |
| Đĩa OS 32 GB Premium (P4) | $5,81/tháng ≈ $0,008/giờ | $0,008 | $0,016 |
| Public IP Standard × 2 (outbound + `fe`) | $0,005/giờ mỗi IP | $0,010 | $0,010 |
| Standard Load Balancer | ~$0,025/giờ (giá chung của Standard LB; Retail API không trả dòng riêng cho East Asia) | $0,025 | $0,025 |
| **Tổng** | | **≈ $0,16/giờ ≈ $3,9/ngày** | ≈ $0,29/giờ ≈ $6,9/ngày |

Ba biện pháp đã áp dụng cho phần AKS: tier Free cho control plane · autoscaler min 1 (node thứ hai chỉ sống khi cần —
phép thử mục 2 tốn chưa tới $0,05) · `make aks-down` cuối buổi (cluster dựng lại trong ~10 phút).

## 5. Sau phép đo: sàn của HPA nâng lên 2

Phép đo zero-downtime (`aks-m9-m10-m2.md`) lộ ra rằng với 1 bản, lần cluster autoscaler gỡ node là một lần gián đoạn
(`be` 503 trong 9 giây). Từ 07:52Z `be` và `fe` chạy 2 bản + `PodDisruptionBudget`. Hệ quả cho M7:

- Mục 1 (HPA 1 → 2 → 1) là số đo thật **với cấu hình min 1**, không còn là hành vi của cấu hình hiện tại: `minReplicas = maxReplicas = 2`.
- Co giãn còn lại ở tầng node (mục 2), và nó **xảy ra thật ở mỗi lần deploy**: `TriggeredScaleUp 1->2` lúc 07:18:58 và
  07:41:55 (pod tạm của CD + pod surge), node thừa bị gỡ sau ~15 phút.
- Right sizing sau khi đổi: app xin 2 × 100m + 2 × 50m = 300m, vẫn vừa node đầu (còn ~400m) lúc bình thường.

# Ảnh chụp — phần ADVANCED: AKS

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Ảnh của bài chính nằm ở `evidence/dXX/screenshots/`.

**Chụp lúc nào.** Tất cả chụp **tối 12/10 (22:26–23:01 giờ VN), sau khi việc đã làm xong** — không phải chụp trong lúc
làm. Trong lúc làm chỉ có log thô (`evidence/raw/aks-*`). Hệ quả phải nói rõ:

- Ảnh GitHub Actions là ảnh của **đúng các lần chạy thật** ban ngày (GitHub giữ lại) — có giá trị như chụp lúc đó.
- Ảnh Portal **lịch sử alert** là ảnh của đúng 2 alert đã Fired ban ngày (Azure Monitor giữ 30 ngày).
- Ảnh Portal của **cluster, node pool, workload, Workbook** và ảnh **ứng dụng** là của cluster **dựng lại lần thứ ba**
  lúc 22:27 riêng để chụp (cluster ban ngày đã `make aks-down`). Cấu hình giống hệt (cùng code, `main` = `a437ba4`),
  nhưng tên node, IP, số liệu trên biểu đồ là của lần dựng này.
- **Không có ảnh** của các khoảnh khắc đã qua: pod `ImagePullBackOff` / `FailedMount`, HPA 1→2→1, node 1→2→1, lúc
  gián đoạn 12 giây. Bằng chứng của chúng chỉ là log thô.

Đã che: email + tên tenant ở góc phải Portal, subscription ID, 2 octet cuối của IP, tên người dùng lưu trong trình duyệt
(ảnh ứng dụng). Chụp bằng Claude in Chrome; ảnh Portal chụp theo vùng (`zoom`) vì chụp toàn trang làm treo tab.

## GitHub Actions và PR

| Ảnh | Cho thấy | Dùng cho |
|---|---|---|
| [`pr94-merged-11-checks-…`](pr94-merged-11-checks-20261012-2229.png) | PR #94 đã merge, tab Checks: 11 (`CI` + `CI — AKS`) | M9 |
| [`cd-aks-run1-rollback-oan-…`](cd-aks-run1-rollback-oan-20261012-2226.png) | Run đầu tiên của `CD — AKS` (`38216996926`): Failure, `Kết quả: rolled_back` | M10 — lỗi bước kiểm (#54) |
| [`cd-aks-run3-simulate-failure-rollback-…`](cd-aks-run3-simulate-failure-rollback-20261012-2227.png) | Run `38219523331`: `simulate_verify_failure` → `rolled_back`, job đỏ đúng | M10 — nhánh rollback |
| [`cd-aks-run5-cluster-tat-bo-qua-…`](cd-aks-run5-cluster-tat-bo-qua-20261012-2227.png) | Run `38257441467`: Success, "Bỏ qua: cluster aks-vsf-dev không tồn tại" | M10 — khi cluster tắt |
| [`cd-aks-run6-success-summary-…`](cd-aks-run6-success-summary-20261012-2226.png) | Run `38262243519`: Success, `Kết quả: deployed`, SHA `512550a` | M10 — end-to-end |
| [`cd-aks-run6-buoc-cho-co-cho-log-…`](cd-aks-run6-buoc-cho-co-cho-log-20261012-2228.png) | Log bước *Chờ cluster có chỗ cho pod lệnh*: lần 1–3 hụt, lần 4 chạy được | M10 — sửa A19 |
| [`cd-aks-run6-rollout-log-…`](cd-aks-run6-rollout-log-20261012-2229.png) | Log rollout `be` → `fe`, `hoi tu sau 0s`, 5/5 lần kiểm, `RESULT=deployed` | M10, M2 |
| [`aks-m6-check-runner-2-be-mat-bi-chan-…`](aks-m6-check-runner-2-be-mat-bi-chan-20261012-2226.png) | Run `38218242391`: runner gọi `fe` và API server, cả hai mã `000` — đạt | M6 |

## Azure Portal

| Ảnh | Cho thấy | Dùng cho |
|---|---|---|
| [`portal-monitor-alerts-2-alert-aks-resolved-…`](portal-monitor-alerts-2-alert-aks-resolved-20261012-2257.png) | Monitor → Alerts, 24 giờ: `AKS: 5xx rate > 5% (be/fe)` Sev1 (2:28 PM) và `AKS: pod không khởi động…` Sev2 (12:10 PM), đều Resolved, trên `log-vsf-aks-jcip0s` | M11 — 2 alert Fired thật |
| [`portal-aks-overview-free-tier-eastasia-…`](portal-aks-overview-free-tier-eastasia-20261012-2258.png) | `aks-vsf-dev`: Running, Kubernetes 1.35.8, East Asia, Pricing tier **Free**, Azure CNI Overlay, 1 node pool, registry `acrvsfjcip0s` | M8, M7 |
| [`portal-aks-node-pool-autoscale-…`](portal-aks-node-pool-autoscale-20261012-2259.png) | Node pool `system`: Scale method **Autoscale**, 1 target / 1 ready | M7 |
| [`portal-aks-workloads-be-fe-2-2-…`](portal-aks-workloads-be-fe-2-2-20261012-2259.png) | Workloads: `fe` 2/2 và `be` 2/2 trong namespace `opsboard`; add-on ở `kube-system` | M1, M10 |
| [`portal-workbook-aks-app-performance-…`](portal-workbook-aks-app-performance-20261012-2300.png) | Workbook *OpsBoard — AKS advanced*: request rate và failure rate theo `be-aks` / `fe-aks` | M11 |
| [`portal-workbook-aks-infra-node-cpu-memory-…`](portal-workbook-aks-infra-node-cpu-memory-20261012-2300.png) | Workbook: bảng thời gian xử lý theo route; CPU node %, memory node % | M11 |
| [`portal-workbook-aks-so-pod-so-node-…`](portal-workbook-aks-so-pod-so-node-20261012-2300.png) | Workbook: số pod theo app (2), số node (1); "Pod không khởi động được": không có | M11, M7 |
| [`portal-workbook-aks-log-be-trace-id-…`](portal-workbook-aks-log-be-trace-id-20261012-2301.png) | Workbook: log của `be` từ `ContainerLogV2` — pod, method, path, status, `trace_id` | M11 — view log |

## Ứng dụng chạy trên AKS

Chụp qua `kubectl -n opsboard port-forward svc/fe 3000:80` (trình duyệt không mở địa chỉ IP dạng HTTP của load
balancer); đường qua load balancer được chứng minh bằng `curl` trong `evidence/raw/aks-verify-*.log`.

| Ảnh | Cho thấy | Dùng cho |
|---|---|---|
| [`app-tren-aks-bang-ticket-…`](app-tren-aks-bang-ticket-20261012-2243.png) | Bảng ticket của OpsBoard với 1 ticket vừa tạo qua `POST /api/tickets` (lưu ở `appdb_aks`) | M3 |
| [`app-tren-aks-thong-ke-…`](app-tren-aks-thong-ke-20261012-2244.png) | Trang thống kê: tổng 1 ticket — `fe` → `be` → MySQL thông | M3 |
| [`app-tren-aks-api-version-sha-…`](app-tren-aks-api-version-sha-20261012-2244.png) | `/api/version` → `{"sha":"a437ba4…"}` = `main` | M1, M10 |
| [`app-tren-aks-api-health-fe-goi-be-…`](app-tren-aks-api-health-fe-goi-be-20261012-2244.png) | `/api/health` → `be_host: "be:8080"`, `be_status: 200` — `fe` gọi `be` bằng tên Service | M3 |

## Chưa có

Ảnh email của 2 alert (hộp thư của người dùng) · ảnh Cost analysis cho `rg-vsf-aks` (dữ liệu trễ 8–24 giờ).

# AKS · tương đương M11 — monitoring

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M11 của đề bài là [`../M11.md`](../M11.md).

Ngày: 2026-10-12 · workspace `log-vsf-aks-jcip0s` + App Insights `appi-vsf-aks-jcip0s` (**riêng**, không dùng chung với bài chính)
Log thô: [`../raw/aks-m11-2026-10-12.log`](../raw/aks-m11-2026-10-12.log) · [`../raw/aks-boom-2026-10-12.log`](../raw/aks-boom-2026-10-12.log) ·
[`../raw/aks-m1-denied-2026-10-12.log`](../raw/aks-m1-denied-2026-10-12.log)

| Mục tiêu của đề | Trên AKS | Trạng thái |
|---|---|---|
| App performance: response time · request rate · failure rate | Workbook *OpsBoard — AKS advanced*, 3 ô đầu, nguồn `AppRequests` | code + dữ liệu có; **chưa có ảnh Workbook** |
| Infra: CPU, memory… | Workbook: CPU/memory node (`Perf`), số pod, số node, pod lỗi | như trên |
| View log | `ContainerLogV2` — log JSON của app trên stdout; `KubeEvents` | **đạt** (mục 2) |
| 3 alert + action group + **trigger thật ít nhất 1** | 3 alert trong `infra/aks/alerts.tf`, action group `ag-vsf-oncall` của bài chính | **2 alert đã Fired thật** (mục 3) |
| Truy vết alert → log/request (brief 21/09) | `trace_id` trong log = `OperationId` trong App Insights | **đạt** (mục 4) |

Khác bài chính ở một điểm phải nói rõ: `topic.md` M11 đòi dashboard **không dùng App Insights** và bài chính đáp ứng bằng
`AppServiceHTTPLogs` của nền tảng. AKS không có log HTTP của nền tảng cho từng request, nên phần app performance ở đây
**dựa vào `AppRequests`** do OpenTelemetry của app gửi về App Insights. Đây là phần advanced, không dùng để đạt M11.

## 1. Dữ liệu có về workspace riêng

Bảng có dữ liệu (đo 07:10Z): `Perf`, `ContainerLogV2`, `KubePodInventory`, `KubeNodeInventory`, `KubeEvents`, `AppRequests`,
`AppDependencies`, `AppExceptions`, `AppMetrics`. `AppRoleName` là `be-aks` / `fe-aks` — đặt qua `OTEL_SERVICE_NAME` và
`WEBSITE_SITE_NAME` trong manifest, không sửa code app.

Lượng thu trong ngày (bảng `Usage`, 07:29Z): `Perf` 3,2 MB · `AppMetrics` 1,2 MB · `ContainerLogV2` 0,8 MB ·
`KubePodInventory` 0,5 MB · còn lại < 0,5 MB — khoảng **6 MB** trên cap 200 MB/ngày. Data collection rule chỉ thu namespace
`opsboard`; workspace của bài chính không nhận một byte nào từ AKS.

## 2. Log

```
ContainerLogV2 | where PodNamespace == "opsboard" and ContainerName == "be"
→ 2026-10-12T07:09:47Z  GET  /items  200  trace_id c70787e71bc2e464daf3040cea3b7056
```

`LogMessage` đã là object JSON (app ghi JSON một dòng/record từ D4) nên lọc theo `path`, `status`, `trace_id` không cần parse.

## 3. Alert — hai lần Fired thật

| Alert | Gây ra bằng | Fired (UTC) | Sau bao lâu | Resolved |
|---|---|---|---|---|
| `AKS: pod không khởi động được (opsboard)` — Sev2 | gỡ `AcrPull` của kubelet → `ImagePullBackOff` (`aks-m1.md`) | **05:10:27** | 2 phút 25 giây | **05:36:36** (tự đóng) |
| `AKS: 5xx rate > 5% (be/fe)` — Sev1 | `scripts/boom.sh` (script của D22, không sửa) vào `be` qua `kubectl proxy`, 1 request/giây, từ 07:25:44 | **07:28:35** | 2 phút 51 giây | xem cuối log thô |
| `alert-vsf-aks-node-cpu-high` | — | chưa bắn | cần CPU node > 80% trong 15 phút; không cố ý gây ra | — |

Lúc alert 5xx bắn, chính query của nó trả: `be-aks` **229 lỗi / 1349 request = 17%** trong 10 phút (ngưỡng 5%, tối thiểu
20 request); `fe-aks` 0 / 280. Nguồn trạng thái: Resource Graph `alertsmanagementresources`. Email đi qua `ag-vsf-oncall`
(action group của bài chính, chỉ tham chiếu) — **chưa có ảnh email** trong repo.

Alert của bài chính không bị kéo theo: `/boom` trên AKS ghi vào workspace riêng, `alert-vsf-5xx-rate` đọc
`AppServiceHTTPLogs` của workspace khác. Chốt chặn sau đó: `../raw/aks-guard-*.log`.

## 4. Truy vết: alert → log → trace

Lấy một dòng bất kỳ của log `/boom` (dòng thứ 20), `trace_id = 07692a4ac2bc24ff0ef43fdbdaf40982`:

| Ở đâu | Tìm bằng | Thấy gì |
|---|---|---|
| Log của `be` (`ContainerLogV2`) | `m.trace_id == "07692a4a…"` | `07:26:03.220Z` pod `be-db965759-6pfgd` · `event=request` · `path=/boom` · `status=500` |
| App Insights `AppRequests` | `OperationId == "07692a4a…"` | `07:26:03.219Z` · `be-aks` · `GET boom` · `ResultCode 500` · 1,1 ms |
| App Insights `AppExceptions` | cùng `OperationId` | `OpsBoard.Common.BoomException` — "loi co y tu /boom de kiem thu alert va logging" |

Trace xuyên hai service (một request `GET /` lúc 07:24:18Z): `fe-aks` `GET /` 124,5 ms → dependency `GET /items`
tới `http://be:8080/items?status=open&limit=20` 115,1 ms — tức `fe` gọi `be` bằng tên Service trong cluster, và
`traceparent` đi theo.

## Giới hạn

- Chưa có ảnh chụp Workbook và ảnh email alert; Workbook mới được kiểm ở mức "Terraform tạo thành công" + từng query chạy
  được qua API, chưa mở trên Portal.
- `alert-vsf-aks-pod-not-starting` không bắt pod kẹt `ContainerCreating` do `FailedMount` (ca M5) — `known-issues.md` A6.
- Không có managed Prometheus/Grafana: CPU/memory lấy từ bảng `Perf` (độ trễ ~1 phút), không có metric tuỳ biến của app.

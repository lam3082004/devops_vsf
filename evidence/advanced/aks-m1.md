# AKS · tương đương M1 — deploy bằng Docker image, pull bằng managed identity

> **PHẦN ADVANCED — ngoài phạm vi `topic.md`.** Bằng chứng M1 của đề bài là [`../M1.md`](../M1.md).

Ngày: 2026-10-12 · cluster `aks-vsf-dev` · ACR `acrvsfjcip0s` (của bài chính, dùng lại)
Log thô: [`../raw/aks-p2-2026-10-12.log`](../raw/aks-p2-2026-10-12.log) (mục M1) · [`../raw/aks-m1-denied-2026-10-12.log`](../raw/aks-m1-denied-2026-10-12.log)

Tiêu chí của đề: *ACR admin user disabled; nơi chạy app pull image bằng managed identity.*

## Luồng pull

```
kubelet trên node  ──►  kubelet identity (managed identity của node pool, AKS tự tạo)
        │                      │ token Entra → đổi lấy token ACR
        ▼                      ▼
   containerd  ◄────────  ACR acrvsfjcip0s   (RBAC: AcrPull trên đúng registry này)
```

Người pull là **node**, không phải pod: manifest không có `imagePullSecrets`, và identity của workload
(`id-vsf-aks-be/fe`) không có quyền gì trên ACR. Image là đúng `vsf-be` / `vsf-fe:<sha>` mà `cd.yml` đã build,
quét Trivy và push — AKS không build lại.

## Bảng bằng chứng

| # | Bằng chứng | Kết quả thật |
|---|---|---|
| 1 | ACR admin user | `adminUserEnabled = false` |
| 2 | Kubelet identity có đúng **một** role | `AcrPull` · scope `…/registries/acrvsfjcip0s` (`az role assignment list --assignee <kubelet> --all`) |
| 3 | Manifest không có secret pull | `imagePullSecrets be=[] fe=[]` |
| 4 | Pull thành công | event `Successfully pulled image "acrvsfjcip0s.azurecr.io/vsf-be:771d909…" in 6.085s` · `vsf-fe:771d909…` in 11.262s |
| 5 | Container chạy đúng image | `fe /api/version` → `{"sha":"771d90998820c62e5fd0250da2719f5c0d82f7b6"}` = tag image của Deployment (`aks-verify`) |

## Chứng minh ngược — gỡ `AcrPull`, pod cần pull phải thất bại

`terraform -chdir=infra/aks apply -var grant_aks_acr_pull=false` → plan **0 to add, 0 to change, 1 to destroy**
(đúng role assignment đó). Rồi đổi `fe` sang một tag **chưa có trên node** (`769e4c9…`, bản trước trong ACR) để
kubelet buộc phải pull — image đang chạy đã nằm trong cache của node nên restart không thôi thì không lộ.

| Thời điểm (UTC) | Sự kiện |
|---|---|
| 05:05:55 | apply: `kubelet_acr_pull[0]: Destruction complete` |
| 05:07:58 | `kubectl set image deployment/fe fe=…/vsf-fe:769e4c9…` |
| 05:08:02 | pod mới `fe-cb796cfc9-swtkt`: **`ErrImagePull`** → `ImagePullBackOff` |
| 05:08:16 | `Failed to pull image …: failed to authorize: failed to fetch anonymous token: … /oauth2/token?scope=repository:vsf-fe:pull…: `**`401 Unauthorized`** |
| 05:08:13 | pod **cũ** vẫn phục vụ: `/api/version` → 200, SHA `771d909…` |

Khác App Service: ở đó mất `AcrPull` thì lần khởi động kế tiếp của container hỏng. Ở đây rolling update
`maxUnavailable 0` giữ pod cũ chạy tới khi pod mới Ready, nên một bản deploy không pull được **không** làm sập
bản đang chạy — sự cố lộ ra ở rollout (và ở alert `alert-vsf-aks-pod-not-starting`), không lộ ra với người dùng.

## Alert bắn thật, rồi trả quyền

| Thời điểm (UTC) | Sự kiện |
|---|---|
| **05:10:27** | **`AKS: pod không khởi động được (opsboard)` — `Fired`, Sev2** (Resource Graph `alertsmanagementresources`), 2 phút 25 giây sau `ErrImagePull` đầu tiên; action group `ag-vsf-oncall` gửi email |
| 05:12:07 | trả quyền: `terraform apply` → `kubelet_acr_pull[0]: Creation complete after 43s`, **1 added** |
| 05:14:19 | `fe` về image `771d909…`: `deployment "fe" successfully rolled out`, `/api/version` → 200 |
| 05:14:21 | `terraform plan` → **No changes** |

Đây cũng là lần **trigger thật** đầu tiên của một alert trên AKS (tương đương dòng "trigger thật ít nhất 1 alert"
của M11) — không phải bấm "Test action group".

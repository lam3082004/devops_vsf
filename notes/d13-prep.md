# D13 — Kế hoạch chi tiết: IP whitelist (M6)

Guide gốc: `docs/guides/d13-ip-whitelist.md` · Bằng chứng: `evidence/M6.md` · Nhật ký: `notes/d13.md` (tạo khi làm).
**AI:** từ D7 được sinh code, PR phải có `## AI usage`. Mọi `apply`/`destroy` trên Azure thật cần bạn chạy — bộ lọc Claude Code chặn `terraform apply` (đã gặp ở D12, lý do `Protected-Scope IaC Apply`).

## Tình trạng đầu vào (đo 2026-09-22)

- **Hạ tầng chưa có một luật truy cập nào.** `grep -rn "ip_restriction\|allowed_ips" infra/` → không kết quả. D13 viết mới hoàn toàn.
- **D12 chưa xong** (apply pha 2 bị chặn). Guide ghi D13 *cần* D12, nhưng thực tế D13 chỉ cần app chạy được và có slot staging — tức là cần **pha 2 của `make up`**, không cần M3/M4/M5 đã đo xong. Có thể làm xen kẽ.
- **D3 đã phát hiện sẵn bẫy SCM** (`notes/d3-cli.md:34-36`): làm bằng CLI thì mặc định
  `scmIpSecurityRestrictionsUseMain = false`, danh sách SCM chỉ có `Deny all` → **chính máy mình cũng 403 vào Kudu**. Portal thì tick sẵn *Use main site rules*. Terraform phải khai rõ.
- Tên thuộc tính đã kiểm bằng `terraform providers schema` (azurerm 4.81), không phải đoán:
  - `site_config.ip_restriction` (block, lặp nhiều lần) — các trường dùng đến: `name`, `ip_address`, `action`, `priority`, `description`.
  - `site_config.ip_restriction_default_action` (string) — đặt `"Deny"`.
  - `site_config.scm_use_main_ip_restriction` (bool).
  - `site_config.scm_ip_restriction` + `scm_ip_restriction_default_action` nếu muốn danh sách SCM riêng.

## Ràng buộc lớn nhất của bài này: lấy đâu ra IP thứ hai

`docs/plans/active/azure-app-service-internship.md` mục Rủi ro đã ghi: **máy làm việc dùng
hotspot điện thoại**, nên cách test mà guide gợi ý (đổi sang hotspot để có IP khác) **không
dùng được** — máy và điện thoại đi chung một IP công khai, curl từ hotspot vẫn ra 200 và
bạn sẽ tưởng luật hỏng.

Bốn cách lấy IP nguồn khác, xếp theo mức nên dùng:

| Cách | Được gì | Mất gì |
|---|---|---|
| **GitHub Actions** (workflow `workflow_dispatch` chỉ curl rồi in IP + mã HTTP) | miễn phí, lặp lại được, log lưu sẵn trên GitHub, **đồng thời là bằng chứng cho quyết định CD ở mục 4 của guide** | phải viết 1 workflow nhỏ |
| **Azure Cloud Shell** | mở trình duyệt là có, IP của Azure | không lưu log tự động, phải chụp |
| Mượn mạng khác (nhà bạn bè, quán) | giống thật nhất | mất công đi |
| VM/VPS region khác | sạch sẽ | tốn tiền, dựng mất thời gian |

Đề xuất: **GitHub Actions cho bằng chứng 403**, Cloud Shell làm lần đo thứ hai cho chắc.

## Decisions cần bạn chốt

**A. SCM dùng chung luật với site chính** → `scm_use_main_ip_restriction = true` cho cả Web App và slot.
Lý do: D3 đã chứng minh để riêng mà quên khai allow thì tự khoá mình khỏi Kudu. Dùng chung
thì mỗi lần sửa IP chỉ sửa một chỗ, không lệch. Nếu muốn chặt hơn (SCM chỉ cho IP nhà, không
cho IP mentor) thì phải khai danh sách riêng — ghi Decision và nhớ rằng mọi thay đổi phải làm hai lần.

**B. IP cá nhân không vào repo.** Thêm `infra/app/terraform.tfvars` vào `.gitignore` (hiện
`.gitignore` **chưa có** mẫu nào cho tfvars) và commit `infra/app/terraform.tfvars.example`.
`var.allowed_ips` kiểu `map(string)` (khoá = tên luật, giá trị = CIDR) chứ không phải list —
để `for_each` theo tên, đổi thứ tự IP không làm Terraform xoá và tạo lại luật khác (cùng lý
do đã chọn `for_each` cho firewall MySQL ở D8).

**C. IPv4 trước, IPv6 ghi vào bẫy.** Chỉ khai luật IPv4, và khi test ép `curl -4`. Lý do:
mạng nhà có IPv6 thì request có thể đi bằng IPv6, không khớp luật IPv4 → tự nhận 403 và mất
thời gian truy nhầm. Nếu sau này thấy IPv6 thật sự được dùng thì thêm luật, đừng thêm mò.

**D. Quyết định cho CD (guide mục 4, dùng lại ở D17): mở tạm IP runner rồi luôn xoá.**
Runner GitHub-hosted không có IP cố định. Cách "mở dải IP GitHub" coi như bỏ — hàng nghìn dải,
không còn là whitelist. Bước dọn phải chạy **kể cả khi job lỗi** (`if: always()`), nếu không
sẽ để lại luật rác và M6 hỏng âm thầm.

## Chuỗi việc

```
[0] chuẩn bị ─▶ [1] PR Terraform ─▶ [2] apply ─▶ [3] test 200 từ máy
                                                   │
[7] make down ◀─ [6] M6.md ◀─ [5] Decision CD ◀─ [4] test 403 từ IP khác
```

### 0. Chuẩn bị (không tốn tiền)

- [ ] Tra IP công khai hiện tại, ép IPv4: `curl -4 -s https://ifconfig.me` (ghi lại, đây là giá trị cho `allowed_ips`).
- [ ] Kiểm xem máy có đang đi IPv6 không: `curl -s https://ifconfig.me` (không ép) — nếu ra địa chỉ dạng `xxxx:xxxx::` thì đọc lại Decision C.
- [ ] Môi trường phải có **slot staging** → cần pha 2 của `make up` xong.

### 1. PR Terraform (không tốn tiền)

- [ ] `infra/app/variables.tf`: `variable "allowed_ips" { type = map(string), default = {} }`, mô tả ghi rõ "giá trị cá nhân, đặt trong terraform.tfvars không commit".
- [ ] `infra/app/app.tf`, trong `site_config` của **cả Web App lẫn slot**:
  ```hcl
  ip_restriction_default_action = "Deny"
  scm_use_main_ip_restriction   = true

  dynamic "ip_restriction" {
    for_each = var.allowed_ips
    content {
      name       = ip_restriction.key
      ip_address = ip_restriction.value
      action     = "Allow"
      priority   = 100 + index(keys(var.allowed_ips), ip_restriction.key) * 10
      # ưu tiên 100, 110, 120… theo thứ tự tên
    }
  }
  ```
- [ ] `.gitignore`: thêm `infra/app/terraform.tfvars` (và `*.auto.tfvars` cho chắc).
- [ ] Tạo `infra/app/terraform.tfvars.example` với IP giả (`203.0.113.10/32`), có commit.
- [ ] Tạo `infra/app/terraform.tfvars` thật, **không** commit — gitleaks không bắt IP, nên đây là kỷ luật của bạn, không có công cụ đỡ.
- [ ] `terraform fmt -check` + `validate`. Plan sẽ ra `2 to change` (app + slot).
- [ ] PR + `## AI usage` → CI xanh → squash merge.
- *Bẫy:* `allowed_ips` rỗng + default action Deny = **khoá tất cả, kể cả bạn**. Đừng apply khi tfvars chưa có IP.

### 2. Apply (TỐN TIỀN — bạn chạy, Claude bị chặn)

- [ ] `terraform -chdir=infra/app plan -out=d13.tfplan` (Claude chạy được, đọc plan giúp bạn).
- [ ] `terraform -chdir=infra/app apply d13.tfplan` (**bạn chạy**).
- [ ] Đợi vài chục giây — luật mới có độ trễ, test ngay dễ thấy kết quả cũ.

### 3. Test 200 từ máy bạn

Bốn bề mặt, ép IPv4:

- [ ] `curl -4 -s -o /dev/null -w '%{http_code}\n' https://<app>.azurewebsites.net/health` → **200**
- [ ] `... https://<app>-staging.azurewebsites.net/health` → **200**
- [ ] `... https://<app>.scm.azurewebsites.net` → **không phải 403** (401 hoặc redirect đăng nhập là đạt)
- [ ] `... https://<app>-staging.scm.azurewebsites.net` → như trên
- [ ] Lưu theo mẫu của guide: `<thời gian ISO>  source_ip=<ip>  GET <url>  → <mã>`

### 4. Test 403 từ IP khác (Decision: GitHub Actions)

- [ ] Thêm `.github/workflows/m6-check.yml`, trigger **chỉ** `workflow_dispatch`, không chạy theo push:
  job in `curl -4 -s https://ifconfig.me` (IP của runner) rồi curl 4 URL, in mã HTTP. Không cần secret, không cần OIDC — chỉ gọi HTTP từ ngoài vào.
- [ ] Chạy workflow, lưu log → 4 URL đều **403**.
- [ ] Lặp lại từ Azure Cloud Shell cho lần đo thứ hai, chụp màn hình.
- *Vì sao phải có bước này:* chứng minh ngược của M6. Chỉ có 200 thì chưa chứng minh được gì —
  app không bật whitelist cũng ra 200.

### 5. Ghi Decision cho CD (dùng lại ở D17)

- [ ] Viết vào plan mục Decisions: CD sẽ **mở tạm luật cho IP runner → verify → xoá luật ở bước `if: always()`**.
- [ ] Ghi rõ vì sao loại 3 cách kia (bảng ở mục 4 của guide).
- [ ] Log của workflow ở bước 4 chính là bằng chứng "runner bị 403 nếu không mở tạm".

### 6. `evidence/M6.md`

- [ ] Bảng 4 bề mặt × 2 nguồn IP (máy bạn / runner) = 8 dòng, mỗi dòng có giờ và mã HTTP.
- [ ] Ảnh Portal → Networking → Access restrictions (che 2 octet cuối nếu repo public).
- [ ] Trả lời 3 câu tự kiểm tra của guide (gợi ý ở cuối file này).
- [ ] Ghi quy trình cập nhật khi IP nhà đổi: sửa `terraform.tfvars` → `apply` → test lại.

### 7. `make down` cuối phiên

- [ ] Kiểm WARP tắt trước khi destroy.
- [ ] `az group list -o table` → không còn `rg-vsf-dev`.

## Bẫy

| Bẫy | Dấu hiệu | Xử lý |
|---|---|---|
| Quên SCM hoặc quên slot | Kudu/staging vẫn mở ra Internet | 4 bề mặt, không phải 2 |
| `allowed_ips` rỗng + default Deny | chính bạn 403 | kiểm tfvars trước khi apply |
| Request đi bằng IPv6 | 403 từ chính máy mình dù luật đúng | `curl -4`, hoặc thêm luật IPv6 |
| Test ngay sau apply | thấy kết quả cũ | đợi vài chục giây |
| Hotspot dùng chung IP với máy | test "IP khác" vẫn ra 200 | dùng GitHub Actions / Cloud Shell |
| IP nhà đổi qua đêm | sáng sau `make up` xong tự 403 | quy trình cập nhật ở mục 6 |
| Luật tạm của CD không bị xoá | whitelist rách âm thầm | bước dọn `if: always()` |

## Gợi ý trả lời 3 câu tự kiểm tra

1. **Vì sao deploy từ runner vẫn được mà gọi HTTP lại 403?** Hai mặt phẳng khác nhau. Deploy đi
   qua **control plane** ARM (`management.azure.com`) và được phép bằng RBAC + OIDC; access
   restriction chỉ áp cho **data plane** của chính app (`*.azurewebsites.net`). Chặn HTTP vào app
   không đụng gì tới quyền sửa resource.
2. **Chặn ở tầng nào?** Ở **front-end của App Service**, trước khi request tới worker chạy
   container. Container không hề thấy request bị chặn — nên 403 không tốn tài nguyên app và
   cũng không xuất hiện trong log ứng dụng.
3. **IP whitelist có thay được xác thực người dùng không?** Không. Nó là kiểm soát tầng mạng,
   không biết ai đang gọi; bất kỳ ai ở trong mạng đã allow đều vào được. Repo này đã ghi nhận
   đúng điểm đó ở Decision R5 (2026-09-21): `be` chỉ chặn theo IP, không xác nhận được request
   đến từ `fe` — chấp nhận vì là công cụ nội bộ và M6 chỉ yêu cầu chặn theo IP.

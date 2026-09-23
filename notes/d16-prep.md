# D16 — Kế hoạch chi tiết: CD pipeline (M10)

Guide gốc: `docs/guides/d16-cd.md` · Bằng chứng: `evidence/M10.md` · Nhật ký: `notes/d16.md` (tạo khi làm)
Phiên trước: `notes/d14.md` (D15 **hoãn**, xem `notes/d15-prep.md`)

## Đọc 60 giây này trước

| | |
|---|---|
| **Tốn tiền?** | **CÓ.** Phải có môi trường bật để deploy vào. `make up` ~25 phút. |
| **Thứ tự BẮT BUỘC** | `make up` **trước** khi merge PR có deploy. Merge trước → CD chạy vào hư không. |
| **Phạm vi** | **Cả `be` và `fe`** — quyết định 2026-09-23. Web App `fe` chưa tồn tại, phải dựng trong bài này. |
| **Trigger** | Tự động theo push `main`. Không phải chạy tay. |
| **Duyệt tay** | **Có**, đúng một chỗ: trước swap. |
| **Ngày dài** | Bước 0 (Terraform `fe`) gần bằng nửa bài. Đừng để nó vào cuối ngày. |

**Hai kỷ luật đã trả giá để học, đừng dính lại:**
- Đừng mở PR hay re-run job trong lúc `make up`/`make down` **chưa xong** — job `terraform plan`
  không phân biệt được trạng thái *dở dang*, sẽ đỏ oan. `known-issues.md` #9 (đã dính 2 lần).
- Đừng mở nhiều PR cùng lúc — `terraform plan` dùng chung concurrency group, các PR huỷ job
  của nhau và `cancelled` hiện thành `fail`. `known-issues.md` #13.

## Ba thứ sẽ vấp nếu không biết trước

### 1. `fe` gọi `be` sẽ bị chính IP whitelist của `be` chặn

`app/fe/src/lib/api.ts:62` đọc `process.env.API_BASE_URL` và gọi `be` **từ phía server**
(comment dòng 2 nói rõ: *"không bao giờ từ `use client`, vì `API_BASE_URL` trỏ tới địa chỉ
nội bộ của backend"*).

Request đó **đi ra Internet rồi vòng lại** bằng outbound IP của App Service, chứ không đi
đường nội bộ. Mà `be` từ D13 đang `ip_restriction_default_action = "Deny"` và chỉ allow IP
nhà. Kết quả: dựng `fe` xong, mọi trang gọi API đều hỏng — và **triệu chứng sẽ trông như lỗi
app** (trang trắng, lỗi fetch) chứ không như lỗi mạng, rất dễ đi truy nhầm sang code `fe`.

Cách chữa đã có sẵn trong repo, dùng lại đúng mẫu đó — `infra/app/db.tf:77` cấp firewall
MySQL bằng:

```hcl
for_each = toset(azurerm_linux_web_app.app.possible_outbound_ip_address_list)
```

Thêm đúng danh sách ấy vào `local.ip_rules` của `be`. **Hai app nằm chung một App Service
Plan nên chung outbound IP** — không cần tra riêng cho `fe`.

> Đánh đổi phải ghi vào Decision: outbound IP **dùng chung cho cả scale unit**, không riêng
> app này. Allow chúng nghĩa là app của khách hàng khác cùng stamp cũng vào được `be`. Đây
> đúng là hạn chế `evidence/M3.md` mục cuối đã nêu cho firewall MySQL, nay lặp lại ở tầng
> HTTP. Chấp nhận được vì R5 đã chốt (Decision 2026-09-21): công cụ nội bộ, M6 chỉ yêu cầu
> chặn theo IP. Muốn chặt hơn thì phải VNet integration + Private Endpoint (S3 trong `topic.md`).

### 2. Hai service nghe hai cổng khác nhau

| Service | Cổng | Khai ở đâu |
|---|---|---|
| `be` | **8080** | `var.container_port`, mặc định 8080 |
| `fe` | **3000** | `app/fe/Dockerfile` (D14) — `ENV PORT=3000 HOSTNAME=0.0.0.0` |

`WEBSITES_PORT` của `fe` phải là **3000**. Dùng lại `var.container_port` cho `fe` là container
lên nhưng App Service gõ nhầm cổng → health check hỏng, log không nói rõ lý do.

### 3. Môi trường thường TẮT, mà CD chạy theo mọi push vào `main`

Repo có kỷ luật `make down` cuối ngày. Nghĩa là phần lớn push vào `main` (PR tài liệu, PR sửa
CI…) rơi vào lúc **không có gì để deploy**. Không chặn trước thì mỗi PR như vậy để lại một run
CD đỏ — hoặc tệ hơn, một **yêu cầu duyệt treo** vì đã bật required reviewer.

Xử lý ở bước 3 (job `preflight`).

## Chuỗi việc

```
[0] Terraform: Web App fe + sửa ip_restriction của be   ← nặng nhất, làm đầu
        ▼
[1] Quyền cho id-gh-deploy (AcrPush + Website Contributor)
        ▼
[2] Hai GitHub environment
        ▼
[3] cd.yml — 3 job
        ▼
[4] Kiểm chứng "chỉ main"  ──▶  [5] Chạy end-to-end  ──▶  [6] evidence/M10.md
```

---

## Bước 0 — Terraform cho `fe` (không tốn tiền tới lúc apply)

Web App `fe` **chưa tồn tại** trong `infra/`. Decision 2026-09-23 đã cảnh báo trước:
*"Khi `fe` được dựng (D16) thì `ip_restriction` + `scm_use_main_ip_restriction` phải khai lại
cho nó và `evidence/M6.md` phải thêm 4 dòng — nếu không, `fe` mở ra Internet trong khi `be`
đã khoá."*

Tạo `infra/app/app-fe.tf` (file riêng, đừng nhồi thêm vào `app.tf` vốn đã dài):

- [ ] `azurerm_linux_web_app` `fe` — **cùng** `service_plan_id` với `be` (không thêm plan → không thêm tiền plan, đúng Q10).
- [ ] `azurerm_linux_web_app_slot` `fe_staging`.
- [ ] Dùng lại `azurerm_user_assigned_identity.app` cho cả hai — **đã có `AcrPull`** (`acr.tf:19`), không cần identity mới. Lý do giữ một identity chung: xem comment đầu `identity.tf`.
- [ ] `app_settings`: `WEBSITES_PORT = 3000` và `API_BASE_URL = "https://${azurerm_linux_web_app.app.default_hostname}"`.
- [ ] **Đủ BA dòng** cho **cả** web app lẫn slot:
      `ip_restriction_default_action = "Deny"` · `scm_use_main_ip_restriction = true` ·
      `scm_ip_restriction_default_action = "Deny"`.
      Thiếu dòng thứ ba là Kudu của `fe` mở ra Internet — đúng lỗ D13 đã bắt được, đọc lại
      comment dài ở `app.tf:96-103` trước khi viết.
- [ ] `dynamic "ip_restriction"` trên `local.ip_rules`, giống `app.tf:105`.
- [ ] `ignore_changes = [site_config[0].application_stack[0].docker_image_name, ...docker_registry_url]` — copy đúng `app.tf:132-135`, nếu không thì `make up` kế tiếp sẽ kéo image về placeholder.
- [ ] `container_registry_use_managed_identity = true` + `container_registry_managed_identity_client_id`.
- [ ] `key_vault_reference_identity_id` — `fe` hiện **không** dùng secret nào, nhưng khai sẵn thì sau này thêm là chạy ngay. Cân nhắc, không bắt buộc.
- [ ] Outputs mới: `fe_url`, `fe_staging_url` trong `outputs.tf`.
- [ ] Biến mới `fe_container_port` (mặc định 3000) nếu muốn khai tường minh thay vì hằng số.

Sửa `be` để `fe` gọi được (phần "vấp" #1):

- [ ] Trong `locals.tf`, nối `azurerm_linux_web_app.fe.possible_outbound_ip_address_list` vào `local.ip_rules` của `be`.
      ⚠️ **Coi chừng vòng phụ thuộc**: `fe` đã trỏ `API_BASE_URL` sang `be`. Terraform chịu được
      vì hai bên dùng thuộc tính khác nhau, nhưng nếu gặp `Cycle:` thì tách bằng cách dùng
      `azurerm_service_plan.plan.id`-level data hoặc khai IP qua `azurerm_linux_web_app.app.possible_outbound_ip_address_list`
      (hai app chung plan nên **cùng** danh sách — cách này đơn giản hơn và không tạo cạnh mới).
- [ ] Ưu tiên ngay cách đơn giản: dùng `azurerm_linux_web_app.app.possible_outbound_ip_address_list` (chính `be`), vì chung plan thì chung IP.

Kiểm trước khi apply:

```bash
terraform -chdir=infra/app fmt -recursive
terraform -chdir=infra/app validate
make plan            # KHÔNG tốn tiền
```

⚠️ `description` của `ip_restriction` **không được chứa dấu phẩy hay chấm phẩy** — ràng buộc
của API Azure, `validate` và `plan` đều không bắt được, chỉ nổ lúc apply sau khi đã mất 5 phút.
`ai-failure-log.md` #23.

## Bước 1 — Quyền cho `id-gh-deploy`

`infra/bootstrap/cicd.tf:99` ghi sẵn: *"Các quyền tạo resource (AcrPush, Website Contributor, …)
sẽ thêm ở D16 khi dựng pipeline CD."* Giờ là lúc đó.

Khai trong **`infra/app`** (không phải bootstrap) vì ACR và Web App sống ở đó. Tra identity
bằng `data` source theo tên — đúng mẫu `keyvault.tf:7` và `ci-permissions.tf:30`, **không**
dùng `terraform_remote_state` (quyết định D7: giữ hai state độc lập).

```hcl
data "azurerm_user_assigned_identity" "gh_deploy" {
  name                = "id-gh-deploy"
  resource_group_name = "rg-vsf-bootstrap"
}
```

| Role | Scope | Để làm gì |
|---|---|---|
| `AcrPush` | ACR | push image |
| `Website Contributor` | **resource group** `rg-vsf-dev` | đổi image slot, swap, sửa access restriction tạm ở D17 |

- [ ] Scope `Website Contributor` ở **resource group**, không phải từng web app — bài này có
      **hai** web app × 2 slot, gán lẻ là 4 assignment và dễ sót slot. Bẫy #5 của guide nói
      đúng chỗ này: *"quyền gán ở scope app nhưng không bao gồm slot"*.
- [ ] Sau khi apply, kiểm thật:
      `az role assignment list --assignee <client-id-deploy> --all -o table`

## Bước 2 — Hai GitHub environment

Hiện **chưa có environment nào** (`gh api repos/lam3082004/devops_vsf/environments` → rỗng).

| Environment | Deployment branch | Required reviewer | Dùng cho job |
|---|---|---|---|
| `staging-deploy` | chỉ `main` | **không** | build + push + set image slot |
| `production` | chỉ `main` | **có** (chính bạn) | swap |

Vì sao **hai** chứ không một: bạn muốn nút duyệt **trước swap**, không phải trước build. Một
environment duy nhất có reviewer sẽ chặn ngay từ bước build, khiến image còn chưa được đẩy lên
mà đã phải bấm duyệt — duyệt cái gì thì chưa rõ.

Tạo bằng web (Settings → Environments → New) hoặc:

```bash
REPO=lam3082004/devops_vsf

# Không reviewer, chỉ giới hạn nhánh
gh api -X PUT "repos/$REPO/environments/staging-deploy" --input - <<'JSON'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON

# Có reviewer là chính mình. `reviewers` là mảng object nên PHẢI truyền qua
# --input (JSON), không đẩy được bằng -f/-F.
gh api -X PUT "repos/$REPO/environments/production" --input - <<JSON
{ "reviewers": [ { "type": "User", "id": $(gh api user --jq .id) } ],
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON

# custom_branch_policies = true mới chỉ MỞ chế độ "Selected branches";
# phải khai thêm đúng nhánh nào, nếu không là chưa giới hạn gì cả:
for ENV in staging-deploy production; do
  gh api -X POST "repos/$REPO/environments/$ENV/deployment-branch-policies" \
    -f name=main -f type=branch
done
```

⚠️ Hai lời gọi, không phải một: `custom_branch_policies: true` chỉ bật chế độ *Selected
branches*; danh sách nhánh là endpoint riêng. Dừng ở lời gọi đầu là environment **không giới
hạn nhánh nào cả** — đúng kiểu "bảo vệ tưởng có mà không có" của D13/D14.

Làm trên web cũng được (Settings → Environments → New), nhanh hơn nếu ngại JSON. Kiểm lại
**bằng đọc, đừng tin là đã đặt**:

```bash
gh api "repos/$REPO/environments" --jq '.environments[] | {name, reviewers: [.protection_rules[]?|select(.type=="required_reviewers")]|length}'
for ENV in staging-deploy production; do
  echo -n "$ENV branches: "
  gh api "repos/$REPO/environments/$ENV/deployment-branch-policies" --jq '[.branch_policies[].name]|join(",")'
done
```

## Bước 3 — `cd.yml`

File **riêng**, không gộp vào `ci.yml` (guide mục 3).

```
preflight                (KHÔNG environment)
  └─ Web App có tồn tại không? → should_deploy=true/false
        │  false → ::notice + dừng XANH
        ▼  true
build-deploy-staging     (environment: staging-deploy)
  └─ build be + fe → push ACR (tag SHA) → set image 2 slot staging
        ▼
swap                     (environment: production — ⏸ CHỜ DUYỆT)
  └─ swap be → swap fe → job summary
```

**Vì sao `preflight` phải nằm NGOÀI environment:** environment protection áp ở **cấp job**.
Để nó trong thì mọi push vào `main` đều sinh một yêu cầu duyệt treo, kể cả khi Azure đang tắt
và chẳng có gì để deploy. Tách ra thì PR tài liệu đi qua êm, không đỏ, không làm phiền ai.

Cách soi state đã có sẵn idiom trong repo — job `terraform plan` ở `ci.yml` làm đúng kiểu này
(`ci.yml`, bước "terraform plan", nhánh `partial`). Với CD thì đơn giản hơn, hỏi thẳng Azure:

```bash
if az webapp show -g rg-vsf-dev -n "app-vsf-$SUFFIX" &>/dev/null; then
  echo "should_deploy=true" >> "$GITHUB_OUTPUT"
else
  echo "should_deploy=false" >> "$GITHUB_OUTPUT"
  echo "::notice::rg-vsf-dev dang trong (da make down) — bo qua deploy. Chay 'make up' roi re-run workflow nay neu muon deploy commit nay."
fi
```

⚠️ Suffix sinh ngẫu nhiên mỗi lần `make up` nên **không hard-code được**. Hai cách lấy:
tra theo tag/prefix (`az webapp list -g rg-vsf-dev --query "[?starts_with(name,'app-vsf-')].name" -o tsv`),
hoặc đọc từ Terraform output. Cách tra theo prefix đơn giản hơn và không cần quyền state.

Yêu cầu khác của guide:

- [ ] `concurrency`: một nhóm deploy duy nhất, **`cancel-in-progress: false`** — swap dở dang
      nguy hiểm hơn là chờ.
- [ ] `permissions`: `contents: read` + `id-token: write`.
- [ ] Đăng nhập ACR **bằng danh tính Entra**, không dùng admin (ACR đã `admin_enabled = false`).
- [ ] Tag image `<acr>/vsf-be:<sha>` và `<acr>/vsf-fe:<sha>` — **không** tag `latest`.
      *(D11 dùng tên repo `vsf-app` cho một service; nay hai service nên tách tên. Ghi Decision.)*
- [ ] Bước Trivy quét lại image sắp push, **cùng chính sách CI** (`CRITICAL,HIGH`, không
      `--ignore-unfixed`) — tuỳ chọn theo guide nhưng nên có, và rẻ vì image vừa build xong.
- [ ] Job summary: SHA, tag, thời gian từng bước, URL.
- [ ] Bước 8 của guide (chờ staging sẵn sàng + đúng SHA) **để D17**. Bài này chờ cố định.

## Bước 4 — Kiểm chứng "chỉ `main` được deploy"

Ba lớp, và phải chỉ ra được **cả ba** (câu tự kiểm tra #1 của guide):

| Lớp | Cơ chế | Hỏng thì sao |
|---|---|---|
| 1 | `on: push: branches: [main]` | nhánh khác không kích hoạt workflow |
| 2 | Deployment branch rule của environment | job bị chặn trước khi chạy |
| 3 | Federated credential `subject = repo:...:ref:refs/heads/main` | token OIDC từ nhánh khác có subject khác → Azure login **thất bại** |

- [ ] Chạy tay workflow từ nhánh `feat/…` → bị environment chặn **hoặc** login Azure thất bại. Chụp.
- [ ] Mở một PR bình thường → CI chạy, **CD không chạy**. Chụp.

> Lớp 3 là lớp chặt nhất vì nó nằm **ngoài** GitHub: kể cả ai đó sửa được workflow và environment,
> Entra vẫn từ chối token không mang đúng subject. Đây cũng là chỗ D6 từng vấp — GitHub bật
> *immutable subject* nên subject thật kèm ID số; repo đã khai **cả hai** dạng
> (`cicd.tf:53` và `:73`). `ai-failure-log.md` #4.

## Bước 5 — Chạy end-to-end (M10)

**Thứ tự bắt buộc**, sai là CD deploy vào hư không:

```
1. warp-cli disconnect          ← WARP làm hỏng cả đo IP lẫn mạng container
2. đo IP công khai nhiều lần    ← CGNAT cho HAI IP, khai cả hai vào terraform.tfvars
3. make up                      ← ~25 phút, ĐỢI XONG HẲN
4. make check-empty / outputs   ← xác nhận môi trường thật sự lên
5. rồi mới merge PR có deploy
```

- [ ] Nhánh `feat/…` đổi một chi tiết **thấy được** (ví dụ trường `msg` trong `/version`).
- [ ] PR → CI xanh (8 job) → squash merge.
- [ ] Mở run CD → chờ tới bước duyệt → **bấm Approve** → chờ swap xong.
- [ ] `/version` của production = SHA commit vừa merge. Kiểm **cả hai** service.
- [ ] Ghi thời gian từng bước.

## Bước 6 — `evidence/M10.md`

- [ ] Link PR · link run CI · link run CD.
- [ ] Bảng thời gian từng bước.
- [ ] Output `/version` **trước và sau**.
- [ ] Ảnh ACR có tag mới (hoặc `az acr repository show-tags` — dạng chữ chặt hơn, xem tiền lệ `evidence/M6.md`).
- [ ] Ảnh nhánh khác không deploy được.
- [ ] **Giải trình về nút duyệt** — xem mục dưới.
- [ ] `evidence/M6.md` thêm **4 dòng** cho 4 bề mặt mới của `fe` (site + SCM × production + slot).
      Không làm là M6 nói dối: tài liệu bảo đã khoá 4 bề mặt, thực tế có 8.

### Phải giải trình: nút duyệt tay và yêu cầu "không thao tác tay"

Guide mục "Xong khi" viết: *"merge → production đổi SHA **không thao tác tay**"*. Bật required
reviewer là chèn đúng một thao tác tay vào giữa.

Không sai, nhưng **phải nói rõ trong `evidence/M10.md`**, đừng để người chấm tự phát hiện:
build → push ACR → deploy slot staging là **hoàn toàn tự động**, không ai chạm vào; người chỉ
duyệt đúng **một** bước cuối là swap vào production. Đó là lựa chọn vận hành có chủ ý (guide
mục 2 cho phép: *"tuỳ chọn: required reviewers"*), đổi lấy việc không có gì vào production mà
không có người nhìn.

Nếu người chấm coi đó là chưa đạt M10: tắt reviewer ở environment `production`, merge lại một
PR nữa, và chụp lần chạy không có bước duyệt. Mất ~10 phút, không phải sửa code.

## Bảng bẫy

| Bẫy | Dấu hiệu | Xử lý | Trạng thái |
|---|---|---|---|
| `make up` kéo image về placeholder | production quay về app mẫu sau khi apply | `ignore_changes` trên `docker_image_name` + `docker_registry_url` | ✅ **đã có sẵn** `app.tf:132-135`; **phải copy cho `fe`** |
| Build trong CD khác bản đã test ở CI | tag base image trôi | ghim base image | ✅ **đã có sẵn** — cả 2 Dockerfile dùng `ARG` với tag ghim |
| CD chạy khi môi trường `down` | deploy thất bại | job `preflight` | ⬜ bước 3 |
| Hai merge liên tiếp → hai CD chồng nhau | swap dở dang | `concurrency` + `cancel-in-progress: false` | ⬜ bước 3 |
| `Website Contributor` không bao gồm slot | set image slot lỗi 403 | gán ở scope **resource group** | ⬜ bước 1 |
| `fe` gọi `be` bị 403 | trang trắng, lỗi fetch — **trông như lỗi app** | allow outbound IP vào `ip_restriction` của `be` | ⬜ bước 0 |
| `fe` sai `WEBSITES_PORT` | container lên nhưng health check hỏng | `WEBSITES_PORT = 3000` | ⬜ bước 0 |
| Kudu của `fe` mở ra Internet | `az ... show` nhìn vẫn như đã khoá | **đủ ba dòng** `*_ip_restriction_*` | ⬜ bước 0 |
| Dấu phẩy trong `description` | `400 BadRequest` lúc apply, `plan` vẫn xanh | bỏ dấu phẩy | ⬜ bước 0 |

## Gợi ý trả lời 3 câu tự kiểm tra

**1. Ba lớp nào bảo đảm "chỉ `main` được deploy"?**
Trigger `on: push: branches: [main]` · deployment branch rule của environment · federated
credential subject `repo:...:ref:refs/heads/main`. Lớp 3 chặt nhất vì nó nằm **ngoài** GitHub —
sửa được workflow và environment vẫn không lấy được token Azure. Bảng đầy đủ ở bước 4.

**2. Vì sao không huỷ CD đang chạy khi có merge mới?**
Vì swap là thao tác **không nguyên tử về phía người quan sát**: huỷ giữa chừng có thể để lại
production trỏ vào một bản, slot trỏ vào bản khác, và không ai biết trạng thái thật là gì cho
tới khi đi đọc từng cái. Chờ thì chậm nhưng luôn kết thúc ở một trạng thái biết được. Đây là
chỗ CD **ngược** với CI: ở CI, `cancel-in-progress: true` là đúng vì huỷ một lần build chẳng
để lại hậu quả nào.

**3. Rollback nhanh nhất sau khi CD xong nhưng bản mới lỗi?**
**Swap lại.** Swap là hoán đổi, nên ngay sau khi swap xong, slot staging đang giữ **đúng bản
production cũ** — swap lần nữa là về chỗ cũ trong vài chục giây, không cần build lại, không
cần đợi image. Chậm hơn nhiều là deploy lại tag SHA cũ (phải kéo image, khởi động container).
Điều kiện để cách nhanh dùng được: **đừng deploy chồng lần thứ hai** trước khi rollback, vì
lần swap sau sẽ đẩy bản tốt ra khỏi slot.

## Ước lượng

| Bước | Thời gian | Tốn tiền |
|---|---|---|
| 0 — Terraform `fe` + sửa `be` | 2 giờ | không (tới lúc apply) |
| 1 — quyền `id-gh-deploy` | 30 phút | không |
| 2 — hai environment | 20 phút | không |
| 3 — `cd.yml` | 1,5 giờ | không |
| 4 — kiểm chứng "chỉ main" | 30 phút | không |
| 5 — end-to-end | 1,5 giờ (25 phút là `make up`) | **CÓ** |
| 6 — `evidence/M10.md` + 4 dòng M6 | 1 giờ | không |

Cuối phiên: **`make down`** nếu còn bật.

## Lưu ý cho phiên có AI

- Mỗi PR phải có mục `## AI usage`.
- Mọi lệnh tốn tiền (`terraform apply`, `make up`, `make down`) phải được xác nhận trong phiên.
- Nợ chưa trả, không chặn D16: 6 ảnh Portal (`notes/screenshot-debt.md`) và D15
  (`notes/d15-prep.md`, chờ repo của intern kia).

# D17 — Kế hoạch chi tiết: Swap an toàn (làm tay, từng bước)

Guide gốc: `docs/guides/d17-safe-swap.md` · Nhật ký: `notes/d17.md` (tạo khi làm) ·
Bằng chứng: thêm mục D17 vào `evidence/M10.md`
Phiên trước: `notes/d16.md` (mục cuối "Rà lại CI/CD 2026-09-24" — pipeline D16 đã kiểm lại, lành)

## Đọc 60 giây này trước

| | |
|---|---|
| **Tốn tiền?** | **CÓ**, nhưng chỉ từ Pha B. Pha A (viết code, PR, merge) làm lúc Azure **tắt**. |
| **Làm gì** | (1) health check + swap warm-up bằng Terraform · (2) `API_BASE_URL` slot-sticky để `fe` staging gọi `be` staging (#15) · (3) thay `sleep 75` bằng **chờ đúng SHA + health 200** · (4) kiểm production sau swap, lỗi thì **swap ngược** · (5) luật IP tạm cho runner, **luôn** gỡ |
| **Thứ tự** | Merge PR D17 lúc Azure **tắt** (CD tự bỏ qua, xanh) → `make up` từ `main` mới → chạy CD bằng `gh workflow run` trên `main`. **Không** `make up` từ nhánh chưa merge (`ai-failure-log.md` #11). |
| **Xong khi** | 5 ô cuối guide: health/warm-up bằng Terraform · CD chờ đúng SHA · rollback tự động · 3 tình huống lỗi có run link · không còn luật tạm |
| **Sau D17** | D18 (M2 zero-downtime) mới đo được có giá trị. |

⚠️ **Môi trường `jcip0s` để BẬT qua đêm 24→25/09 theo quyết định của người dùng** (rà lại lần hai + test luồng thật, `notes/d16.md` mục
"Bug lọt qua D16"). **`make down` trước khi bắt đầu D17** — Pha A của D17 làm lúc Azure tắt.

**Kỷ luật đã trả giá, đừng dính lại** (`known-issues.md`):
- Đừng mở PR / re-run job khi `make up`/`make down` **chưa xong** (#9).
- Đừng mở nhiều PR cùng lúc — các tình huống lỗi ở Pha C phải làm **tuần tự**, PR sau chỉ mở khi
  run CD của PR trước đã xong (#13).
- Đo IP nhà **nhiều lần** trước khi khai whitelist (#11). Tắt WARP = Claude Code mất mạng; làm một mạch.

## Bốn quyết định phải chốt TRƯỚC khi viết code

Ghi câu trả lời vào `notes/d17.md` mục Decisions. Cột "Đề xuất" là gợi ý, không phải đã chốt.

| # | Câu hỏi | Lựa chọn | Đề xuất |
|---|---|---|---|
| A | Health check / warm-up path của `fe`? `fe` **không có** `/health`, chỉ có `/api/version` | (a) `/api/version` — chỉ chứng minh process sống · (b) route mới `/api/health` gọi `be` `/health` | **(a) cho health check nền tảng + warm-up.** (b) làm `fe` bị đánh dấu hỏng khi `be` hỏng — restart `fe` không chữa được `be`, chỉ làm tệ thêm |
| B | CD kiểm "fe staging nói chuyện được với be staging" (#15) bằng gì? Các trang của `fe` trả **200 kèm banner lỗi** khi `be` chết, nên mã HTTP của trang không chứng minh gì | (a) không kiểm, chỉ tin cấu hình · (b) thêm `/api/health` ở `fe` (gọi `be` `/health` qua `API_BASE_URL`, trả kèm host đã gọi) và **chỉ CD poll** nó, không dùng làm health check nền tảng | **Khuyến nghị mạnh (b).** Bằng chứng mới: PR #46 (`notes/d16.md` mục "Bug lọt qua D16", `known-issues.md` #18) — kiểm SHA không đủ, CD + `evidence/M10.md` đều xanh suốt D16 trong khi UI production `fe` đóng băng banner lỗi cả buổi, không ai bắt được vì không có gì poll việc `fe` gọi được `be` thật. Nhỏ (một route), và là thứ duy nhất chứng minh được #15 đã chữa bằng số đo. Kèm 1–2 test → bắt đầu đóng #16 luôn |
| C | Rollback tự động (bước 10b) có được **chạy thật** không? 3 tình huống của guide đều dừng **trước** swap, nên code swap ngược không bao giờ chạy | (a) không thử, chỉ đọc code · (b) thêm input `workflow_dispatch` `simulate_verify_failure` (mặc định `false`) làm bước kiểm production cố ý so sai SHA | **(b).** Code rollback chưa từng chạy = chưa có rollback. Input chỉ dùng được trên `main` (lớp 3 vẫn chặn nhánh khác). Giá: một nhánh `if` trong pipeline production — ghi rõ trong comment |
| D | `WEBSITES_CONTAINER_START_TIME_LIMIT`? | để mặc định (230s) · đặt thấp (vd 120) | **Đo trước rồi mới đặt.** Xem log thời gian khởi động thật ở Pha C1; đặt ~3× số đo. Không có số đo thì để mặc định và ghi vậy |

## Hiểu trước khi làm — 5 điều quyết định thiết kế

1. **IP runner khác nhau giữa các job.** Mỗi job GitHub Actions chạy trên một máy riêng. Nếu thêm
   luật tạm ở job `build-deploy-staging` rồi kiểm production ở job `swap`, IP đã khác → 403.
   ⇒ Dồn **poll staging → swap → kiểm production → rollback → dọn luật** vào **một job** (`swap`).
   Job `build-deploy-staging` chỉ còn build + push + đặt image; **xoá bước `sleep 75`**.
2. **Access restriction KHÔNG đi theo swap** (nằm trong nhóm setting "không swap" của App Service).
   Luật thêm vào slot nào thì ở lại slot đó. ⇒ Thêm vào **4 bề mặt** (`be`, `be`-staging, `fe`,
   `fe`-staging), gỡ đúng 4 bề mặt đó. *(Nếu đo thấy khác — ghi vào `notes/d17.md`.)*
3. **Sticky setting phải khai CÙNG LÚC với việc cho giá trị hai slot khác nhau.** Nếu cho
   `API_BASE_URL` của slot khác production mà **quên** sticky, lần swap đầu sẽ **mang**
   `API_BASE_URL` của staging lên production → `fe` production gọi `be` **staging**. Không ai báo
   lỗi, chỉ có dữ liệu "lạ". `terraform plan` sau swap sẽ lộ ra drift — đó là cách phát hiện.
4. **`if: always()` CÓ chạy khi job bị huỷ**, nhưng **không** chạy khi runner chết giữa chừng. Guide
   (mục Bẫy) nói "bước dọn không chạy khi job bị huỷ" — chỉ đúng với trường hợp runner mất. ⇒ Vẫn
   cần lưới an toàn: `terraform plan` sau mỗi lần thử (luật lạ = drift) và tuỳ chọn một bước quét
   luật mồ côi tên `cd-*` ở `preflight`.
5. **Hai lớp chặn swap, độc lập nhau.** Lớp của CD (poll SHA + health, bước 8c/8d) và lớp của
   Azure (warm-up với `WEBSITE_SWAP_WARMUP_PING_STATUSES=200` — theo docs, mã không nằm trong danh
   sách thì swap dừng). Tình huống 2 và 3 ở Pha C chủ yếu thử lớp CD, vì CD dừng trước khi gọi swap.

---

## Pha A — Viết code (KHÔNG tốn tiền, Azure tắt) · ~3 giờ

Nhánh: `git fetch && git switch -c feat/d17-safe-swap origin/main`

### A1. Health check + warm-up — `infra/app/app.tf` (be) và `infra/app/app-fe.tf` (fe)

Cho **cả site lẫn slot** (4 khối `site_config`):

- [ ] `health_check_path` = `/health` (be) · `/api/version` (fe, theo quyết định A)
- [ ] `health_check_eviction_time_in_min` — khai cùng path (khoảng 2–10); chọn và ghi lý do
- [ ] Xoá dòng comment `# health_check_path = "/health" bật ở D17 — image mẫu không có /health.`
      (`app.tf`, ngay trên `application_stack` của site `be`) và thay bằng comment nói hệ quả với
      image placeholder (xem bẫy P1 bên dưới)

App settings (dùng chung site + slot, **không** sticky) — thêm vào `local.app_settings` (be) và
`local.fe_app_settings` (fe):

- [ ] `WEBSITE_SWAP_WARMUP_PING_PATH` = `/health` (be) · `/api/version` (fe)
- [ ] `WEBSITE_SWAP_WARMUP_PING_STATUSES` = `200` — **chỉ** 200; 503 (DB lỗi) không phải "sẵn sàng"
- [ ] (theo quyết định D) `WEBSITES_CONTAINER_START_TIME_LIMIT`
- [ ] `always_on = true` — **đã có** ở cả 4 khối, chỉ cần xác nhận

Kiểm: `terraform -chdir=infra/app fmt -check && terraform -chdir=infra/app validate`

### A2. `API_BASE_URL` slot-sticky — `infra/app/app-fe.tf` (đóng `known-issues.md` #15)

- [ ] Thêm vào `locals.tf`, cạnh `be_hostname`:
      `be_staging_hostname = "${local.be_app_name}-staging.azurewebsites.net"` — vẫn là chuỗi
      tính tay, **không** đọc `azurerm_linux_web_app_slot.staging.default_hostname` (đọc là mở lại
      cạnh `fe`→`be`, `Cycle:` — `notes/d16.md`)
- [ ] Slot `fe_staging`: `app_settings = merge(local.fe_app_settings, { API_BASE_URL = "https://${local.be_staging_hostname}" })`
- [ ] Site `fe` (resource `azurerm_linux_web_app.fe`, **không** phải slot):
      ```hcl
      sticky_settings {
        app_setting_names = ["API_BASE_URL"]
      }
      ```
- [ ] Cập nhật comment `local.fe_app_settings`: bỏ câu "dùng chung site + slot" cho riêng
      `API_BASE_URL`, trỏ sang #15
- [ ] `be` staging **đã** allow outbound IP của `fe` (`local.be_ip_rules` dùng cho cả slot,
      `app.tf`) — không cần sửa, chỉ xác nhận khi đọc code
- [ ] `terraform -chdir=infra/app validate` — `validate` đã bắt được `Cycle:` (reviewer đã thử:
      `merge(... API_BASE_URL = be-staging)` + `sticky_settings` validate sạch, không vòng)

### A3. (quyết định B) Route `/api/health` của `fe` — `app/fe/src/app/api/health/route.ts`

- [ ] `export const dynamic = "force-dynamic"` — cùng lý do với `/api/version` (không có dòng này
      Next prerender lúc build, route trả kết quả đóng băng)
- [ ] Gọi `${API_BASE_URL}/health` có timeout (vài giây); trả `200` khi `be` 200, `503` khi không,
      body có **host đã gọi** (chỉ hostname, không secret) để CD in ra "fe-staging → app-…-staging"
- [ ] 1–2 test (khung test cho `app/fe` chưa có — #16; đây là lúc chọn vitest/jest + script `test`
      trong `package.json` + bước chạy trong job `frontend` của `ci.yml`). Nếu thấy phình, tách PR riêng
- [ ] `make fe-lint && make fe-build` — build phải in `ƒ /api/health` (dynamic), không phải `○`
- [ ] Cổng CI chặn prerender tĩnh **đã có** (`ci.yml` job `frontend`, thêm sau bug #46 —
      `known-issues.md` #18): nó tự đọc `.next/prerender-manifest.json` sau `next build` và fail
      nếu bất kỳ route nào (ngoài `/_...` và `/favicon.ico`) bị prerender tĩnh. `/api/health` mới
      thêm ở đây **phải** ra `ƒ`; nếu quên `export const dynamic = "force-dynamic"` (hoặc quên gọi
      `connection()`/fetch no-store) thì cổng này tự bắt được, không cần nhớ kiểm tay

### A4. `cd.yml` — viết lại luồng chờ + swap

**Job `build-deploy-staging`:** xoá bước "Chờ container khởi động (thời gian cố định)" (`sleep 75`) và
comment dài ngay trên nó. Mọi thứ khác giữ nguyên.

**Job `swap`** — thứ tự bước mới (giữ nguyên logic swap `be` trước `fe` + cờ `be_swapped` hiện có):

| # | Bước | Ghi chú thực thi |
|---|---|---|
| 1 | Đăng nhập Azure OIDC | như cũ |
| 2 | IP công khai runner | `curl -4 -s --max-time 15 https://api.ipify.org`, **kiểm đúng dạng IPv4** trước khi dùng (rỗng → fail sớm, đừng thêm luật `/32` rỗng) |
| 3 | Thêm luật tạm vào **4 bề mặt** | tên `cd-${{ github.run_id }}-${{ github.run_attempt }}` (re-run không đụng luật cũ) · `--priority` < 100 (IP nhà bắt đầu 100) · `--description` ASCII, ≤ 64 **byte**, không `,`/`;` (#23, #30) · lệnh: `az webapp config access-restriction add -g rg-vsf-dev -n <app> [--slot staging] --rule-name … --action Allow --ip-address <ip>/32 --priority … --description …` |
| 4 | Poll staging | mỗi 5s, tối đa ~300s. **Đạt** khi đủ cả: `be`-staging `/version` sha = `github.sha` **và** `/health` 200 · `fe`-staging `/api/version` sha = `github.sha` · (quyết định B) `fe`-staging `/api/health` = **200** — in kèm host mà `/api/health` báo đã gọi (bằng chứng `fe`-staging thật sự nói chuyện với `be`-staging, không chỉ SHA khớp). Luật tạm vừa thêm có thể 403 vài giây — 403 là "chưa", không phải "hỏng". `curl --max-time` mỗi lần gọi |
| 5 | Hết giờ → **dừng, không swap**, job đỏ | in lần gọi cuối của từng URL (mã + body rút gọn) để biết vì sao |
| 6 | Swap `be` → swap `fe` | giữ nguyên code hiện tại |
| 7 | Kiểm production | `be` `/version` = sha + `/health` 200 · `fe` `/api/version` = sha · (quyết định B) `fe` `/api/health` = **200**, in kèm host đã gọi — **cùng kiểm phải làm ở production**, không chỉ ở staging (bài học #46/#18: SHA đúng không chứng minh `fe` gọi được `be`) — **N lần liên tiếp** (vd 5 lần cách 5s), không phải một lần. (quyết định C) `simulate_verify_failure=true` → so với sha sai |
| 8 | Lỗi ở 6 (swap `fe` hỏng sau khi `be` đã swap) **hoặc** ở 7 → **swap ngược** mọi app đã swap | ngược thứ tự: `fe` trước rồi `be` · chỉ swap ngược app **đã** swap · job đỏ · summary ghi rõ "đã rollback" và production đang ở SHA nào |
| 9 | Dọn luật — `if: always()` | gỡ trên 4 bề mặt, mỗi lệnh tự chịu lỗi (luật chưa kịp thêm thì remove báo lỗi — không được làm hỏng các lệnh sau), **rồi đọc lại** `az webapp config access-restriction show` và **fail nếu còn** `cd-${run_id}-…` |
| 10 | Summary — `if: always()` | thêm: IP runner, số giây chờ staging, kết quả kiểm production, có rollback không |

Thêm vào `on.workflow_dispatch` (quyết định C):
```yaml
    inputs:
      simulate_verify_failure:
        description: "D17: co y lam buoc kiem production that bai de thu rollback"
        type: boolean
        default: false
```
Với `push` thì `inputs.simulate_verify_failure` rỗng → coi như `false`. Kiểm kỹ biểu thức này.

Tuỳ chọn (làm nếu còn sức): bước ở `preflight` liệt kê luật tên `cd-*` còn sót trên 4 bề mặt và
gỡ/cảnh báo — lưới cho trường hợp runner chết (điều 4 ở trên). `preflight` dùng cùng `id-gh-deploy`
nên đã có quyền `Website Contributor`.

Cập nhật comment đầu job `swap` và comment `concurrency` cho khớp luồng mới.

### A5. Kiểm tĩnh (không tốn tiền) — phải xanh hết trước khi mở PR

```bash
export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$HOME/.nvm/versions/node/v24.21.0/bin:$PATH
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/cd.yml'))"
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -no-color -oneline
terraform -chdir=infra/app fmt -check -recursive && terraform -chdir=infra/app validate
make lint && make test && make fe-lint && make fe-build
```
`DOTNET_ROOT`/`PATH` trước mọi lệnh `dotnet`/`node`: dotnet hệ thống hỏng, node hệ thống là 18 (<
20 mà Next 16 cần). Mốc hiện tại để so: actionlint trên `main` chỉ có **1** ghi chú style (SC2129,
`cd.yml` bước probe). Mọi cảnh báo mới do D17 sinh ra phải đọc và xử lý hoặc giải thích.

`terraform fmt -check` ở `infra/app` sẽ báo `terraform.tfvars` (file local, gitignored, CI không
thấy) chưa format — không phải lỗi của D17. Chạy `terraform fmt infra/app/terraform.tfvars` một
lần ở máy để hết cảnh báo, hoặc bỏ qua đúng dòng đó khi đọc kết quả.

Tự đọc lại bằng mắt 3 chỗ `bash -n`/actionlint **không** bắt được:
- [ ] Bước dọn thật sự có `if: always()` và không phụ thuộc output của bước có thể chưa chạy
- [ ] Không có `set -e` nào làm vòng poll chết ở lần `curl` lỗi đầu tiên
- [ ] Không in token/secret; IP runner in ra là chấp nhận được (IP công khai của Azure)

### A6. PR → CI → merge (Azure vẫn tắt)

- [ ] PR có mục `## AI usage` (ghi rõ phần nào AI viết — kể cả kế hoạch này)
- [ ] 8/8 required check xanh. Job `terraform plan (infra/app)` lúc Azure tắt chỉ plan phần nhỏ —
      bình thường
- [ ] Squash merge → CD chạy → `preflight` xanh, 2 job sau **skipped** (Azure tắt). Đây là kiểm
      chứng đầu tiên: YAML mới chạy được và không deploy vào hư không.
      Lệnh xem: `gh run list -w CD -L 1` rồi `gh run view <id>`

---

## Pha B — Bật môi trường (TỐN TIỀN) · ~40 phút

- [ ] **B1.** `git switch main && git pull` ở checkout sẽ chạy `make` (xác nhận `git log -1` = commit
      merge của PR D17)
- [ ] **B2. BẮT BUỘC, không tuỳ chọn.** Whitelist hiện tại của lần dựng `jcip0s` sai **3/3** địa
      chỉ (`known-issues.md` #19): `cong-ty` = `104.30.x.x` là IP thoát Cloudflare WARP (dải
      anycast dùng chung, không phải IP nhà), còn `mentor`/`nha-lam` = `198.51.100.x`/`203.0.113.x`
      là dải tài liệu RFC 5737 — **không bao giờ route được trên Internet thật**, dùng để test là
      vô dụng. `warp-cli disconnect` → đo IP: 40 lần `curl -4 -s https://api.ipify.org` (+ vài lần
      `ifconfig.me`) → khai **mọi** IP đo được (chỉ IP thật, không dùng lại 3 giá trị cũ) vào
      `infra/app/terraform.tfvars` → `warp-cli connect`
- [ ] **B3.** ⚠️ **Xác nhận trước (tốn tiền).** `make up` — **3 pha**, đợi xong hẳn (`Apply complete`, `rc=0`). Không mở PR trong lúc này
- [ ] **B4.** Kiểm cấu hình thật (chỉ đọc):
      ```bash
      BE=$(az webapp list -g rg-vsf-dev --query "[?starts_with(name,'app-vsf-')].name" -o tsv)
      FE=$(az webapp list -g rg-vsf-dev --query "[?starts_with(name,'fe-vsf-')].name" -o tsv)
      for A in $BE $FE; do for S in "" "--slot staging"; do
        echo "== $A $S"
        az webapp config show -g rg-vsf-dev -n $A $S --query "{hc:healthCheckPath, alwaysOn:alwaysOn}" -o tsv
        az webapp config appsettings list -g rg-vsf-dev -n $A $S \
          --query "[?starts_with(name,'WEBSITE_SWAP') || name=='API_BASE_URL'].{n:name,v:value,sticky:slotSetting}" -o tsv
      done; done
      ```
      Mong đợi: `hc` đúng path ở cả 4 · `API_BASE_URL` của `fe` production trỏ `app-…` còn của
      `fe` staging trỏ `app-…-staging`, **cả hai `sticky=True`** · warm-up setting có ở cả 4, `sticky=False`
- [ ] **B5.** `terraform -chdir=infra/app plan` → **No changes** (mốc sạch để so sau mỗi run CD).
      Môi trường `jcip0s` từng có drift ở đây: khối `logs` của `fe` (http_logs file_system,
      retention 3 ngày/100 MB, `detailed_error_messages=false`) bị bật **tay** trên Azure (Portal
      hoặc `az`, không có trong code) — không phải bug code, nhưng **đừng bật log bằng tay** trên
      Portal/CLI ở D17 nữa; logging thuộc D21, khai bằng Terraform. Nếu B5 thấy drift dạng này:
      ghi lại nguồn (ai/khi nào bật tay) **trước khi** `apply` để xoá nó
- [ ] **B6.** Ghi lại cho bẫy P1: `curl` production `be` `/health` trên image placeholder ra mã gì,
      và blade Health check trên Portal báo gì. Chỉ quan sát, không sửa

---

## Pha C — Chạy các tình huống (TỐN TIỀN) · ~1.5–2 giờ

Sau **mỗi** run: ghi link run + kết quả vào `notes/d17.md`, và làm **bộ kiểm sau run** (C6).
Làm **tuần tự** — không mở PR mới khi run CD trước chưa xong.

### C1. Bình thường
- [ ] ⚠️ **Xác nhận trước** — mọi run CD ở Pha C là **swap thật trên Azure** (luật `CLAUDE.md`).
      Làm C1 **đầu tiên**, trước C2–C4, và trong vòng **1 giờ** sau khi B3 xong (bẫy P1)
- [ ] `gh workflow run cd.yml --ref main` (không cần PR — lớp 3 cho phép `main`)
- [ ] **Nếu swap đỏ ở warm-up của Azure** (không phải ở bước poll của CD): đọc activity log +
      log swap **trước** khi nghi app. Rủi ro chưa kiểm: warm-up nội bộ của nền tảng có thể nhận
      403 (`ip_restriction_default_action=Deny`) hoặc redirect (`https_only`) — trước D17 statuses
      để mặc định (mọi mã đều qua) nên các swap D11/D16 **không** chứng minh điều ngược lại. Nếu
      đúng vậy: ghi vào `notes/d17.md`, cân nhắc thêm luật allow dải nội bộ, **hỏi trước khi đổi M6**
- [ ] Mong đợi: poll đạt sau X giây (ghi X — đây là số đo thay cho `sleep 75`) → swap → kiểm
      production đạt → dọn luật → xanh
- [ ] `curl` từ máy nhà: production `be` `/version` và `fe` `/api/version` = SHA của `main`
- [ ] (quyết định B) log poll có dòng `fe-staging → app-…-staging` — **bằng chứng #15 đã chữa**
- [ ] Ghi thời gian khởi động container thật (log stream / log poll) → chốt quyết định D

### C2. Bản mới không khởi động
- [ ] ⚠️ Xác nhận trước (merge = CD chạy thật). PR nhánh `chore/d17-no-start`: `app/be/Dockerfile` đổi `ENTRYPOINT` sang một `.dll` không tồn tại.
      CI **vẫn xanh** vì CI chỉ build + Trivy, không chạy container — đó chính là lý do tình huống
      này lọt được tới CD
- [ ] Merge → CD: poll hết giờ → **không swap** → job đỏ
- [ ] Kiểm: production `/version` vẫn là SHA C1 · luật tạm đã gỡ (C6)
- [ ] PR revert (`git revert`) → merge → CD xanh (tính là thêm một lần "bình thường")

### C3. Bản mới chạy nhưng `/health` 503
- [ ] ⚠️ Xác nhận trước. PR nhánh `chore/d17-health-503`: thêm `ENV DB_PORT=1` vào stage runtime của `app/be/Dockerfile`.
      Vì sao cách này: `Config.cs` đọc `DB_PORT` (mặc định 3306) mà Terraform **không** đặt
      `DB_PORT` trong app settings → giá trị trong image có hiệu lực → app vẫn khởi động
      (`Program.cs`: DB lỗi chỉ cảnh báo) nhưng `/health` 503. `/version` **đã** ra SHA mới —
      đúng ca "đúng SHA nhưng chưa sẵn sàng"
- [ ] Mong đợi: poll thấy SHA khớp nhưng health 503 → hết giờ → không swap → đỏ
- [ ] Revert qua PR, như C2

### C4. Rollback tự động (quyết định C)
- [ ] ⚠️ Xác nhận trước. `gh workflow run cd.yml --ref main -f simulate_verify_failure=true`
- [ ] Mong đợi: poll đạt → swap → kiểm production **thất bại cố ý** → swap ngược `fe` rồi `be` →
      job đỏ, summary ghi "đã rollback"
- [ ] Cái bẫy của phép thử này: run chạy tay build lại **đúng SHA** production đang chạy, nên
      "production vẫn là SHA cũ" **không** chứng minh được gì. Bằng chứng phải là **số lần swap**:
      ```bash
      az monitor activity-log list -g rg-vsf-dev --offset 1h \
        --query "[?contains(operationName.value,'slotsswap') && status.value=='Succeeded'].{t:eventTimestamp,r:resourceId}" -o table
      ```
      Mỗi swap ghi 2 sự kiện (Started + Succeeded) nên phải lọc `Succeeded`; activity log có thể
      trễ vài phút. Mong đợi trong cửa sổ run: mỗi app **2** swap thành công (đi + về), `fe` về trước `be` —
      cộng log job có dòng rollback. Chạy xong vẫn C6 như mọi run

### C5. Luật tạm (tình huống thứ 3 của guide)
- [ ] Sau C1–C4: không bề mặt nào còn luật tên `cd-*`:
      ```bash
      for A in $BE $FE; do for S in "" "--slot staging"; do
        az webapp config access-restriction show -g rg-vsf-dev -n $A $S \
          --query "ipSecurityRestrictions[?starts_with(name,'cd-')].name" -o tsv
      done; done      # phải KHÔNG in gì
      ```
- [ ] Chụp blade Access restrictions của 1 bề mặt sau run (ảnh cho `evidence/`)

### C6. Bộ kiểm sau mỗi run (1 phút)
- [ ] Lệnh ở C5 → rỗng
- [ ] `terraform -chdir=infra/app plan` → **No changes** (luật lạ hoặc `API_BASE_URL` bị swap nhầm
      đều hiện ra ở đây)
- [ ] M6 đo lại một lần cuối Pha C: `gh workflow run m6-check.yml -f app=$BE -f expect=403`, rồi
      lần nữa với `app=$FE` — cả 8 bề mặt phải 403 từ runner (Decision 2026-09-23: đổi CD thì đo lại M6)

---

## Pha D — Ghi chép (không tốn tiền, làm TRƯỚC `make down` nếu cần số đo từ Azure)

- [ ] `notes/d17.md`: thứ tự thật đã làm, 4 quyết định A–D, link run C1–C5, số giây chờ staging,
      thứ gì kế hoạch này nói sai
- [ ] `evidence/M10.md`: thêm mục "D17 — swap an toàn" (link run + log poll + log rollback)
- [ ] `known-issues.md`: #15 → chuyển sang đã chữa (kèm số đo C1) · #16 nếu có test `fe` · **#18
      đóng nốt phần "CÒN MỞ"** khi `/api/health` đã chạy thật (poll cả staging lẫn production) ở C1
- [ ] `ai-failure-log.md` nếu AI sinh sai (hiện 30 case)
- [ ] Plan `docs/plans/active/azure-app-service-internship.md`: tick D17, Recovery 1 dòng
- [ ] 6 ảnh Portal còn nợ (`notes/screenshot-debt.md`) — tranh thủ lúc môi trường bật
- [ ] **M8 lần 2 — quyết định rõ:** B3 là một lần `make up` từ môi trường trống trên code mới;
      nếu chạy trơn (không sửa code giữa chừng) **và** E trơn thì có thể dùng làm bằng chứng
      `evidence/M8.md` lần 2 cho tầng `infra/app`. Tầng `infra/bootstrap` vẫn chưa được kiểm (#17)

## Pha E — Tắt (BẮT BUỘC)

- [ ] ⚠️ Xác nhận trước (destroy). Không còn run CD nào đang chạy: `gh run list -w CD -L 3`
- [ ] `make down` → đợi `Destroy complete` → `make check-empty` → "rg-vsf-dev khong ton tai — OK"
- [ ] `az group list --query "[].name" -o tsv` chỉ còn `rg-vsf-bootstrap` + 2 RG mặc định

---

## Bảng bẫy

| # | Bẫy | Hậu quả | Tránh |
|---|---|---|---|
| P1 | Health check bật trong lúc cả 4 bề mặt còn chạy **image placeholder** (`dotnet/samples:aspnetapp` — không có `/health` lẫn `/api/version`, trả 404) | cả 4 bề mặt "unhealthy" từ B3 tới C1. Một instance thì không bị loại, nhưng unhealthy **quá 1 giờ** thì nền tảng thay instance. Sau C1, hai slot staging giữ lại placeholder nên vẫn báo unhealthy | Giữ B3 → C1 **dưới 1 giờ**; ghi lại (B6); **đừng** đổi path cho khớp placeholder |
| P2 | Cho `API_BASE_URL` hai slot khác nhau mà quên `sticky_settings` | swap mang URL staging lên production, `fe` production gọi `be` staging | Khai trong **cùng** commit; B4 kiểm `sticky=True`; C6 `plan` phải No changes |
| P3 | Luật tạm thêm ở job này, kiểm ở job khác | IP runner khác → 403 | Một job duy nhất cho poll → swap → kiểm → rollback → dọn |
| P4 | `set -e` trong vòng poll | `curl` lỗi lần đầu (403 vài giây sau khi thêm luật) giết job | Vòng poll tự bắt lỗi từng lần gọi |
| P5 | `description` luật tạm có dấu tiếng Việt / dấu phẩy / > 64 byte | 400 lúc `access-restriction add`, **chỉ lộ khi chạy thật** | ASCII, ngắn, đếm bằng `len(s.encode())` |
| P6 | Rollback gọi swap cho app **chưa** swap | đổi production của app đó sang bản cũ hơn — lệch phiên bản | Chỉ swap ngược app có cờ đã swap; `fe` trước `be` |
| P7 | Re-run job `swap` sau khi nó đã swap xong | swap lần 2 = đưa bản cũ lên lại | Re-run **cả workflow**, không re-run job lẻ sau khi đã swap; ghi vào summary |
| P8 | `terraform apply` trong lúc CD đang chạy | apply xoá luật tạm (drift) giữa lúc CD poll → 403 → hết giờ | Không apply khi `gh run list -w CD` còn run `in_progress` |
| P9 | Swap ngược khi staging đã bị deploy đè (guide) | quay về bản sai | Chỉ swap ngược trong **cùng run**; `concurrency: cd-deploy` không huỷ ngang giữ điều này |
| P10 | Mở PR revert (C2/C3) trong lúc run CD trước chưa xong | hai run xếp hàng — không nguy hiểm, nhưng log hai tình huống trộn nhau, khó đọc bằng chứng | Đợi run xong mới mở PR tiếp |
| P11 | **CD xanh nhưng UI hỏng** — kiểm SHA (`/version`) ≠ kiểm chạy được thật. Đã xảy ra suốt D16 (PR #46, `known-issues.md` #18): `fe` prerender tĩnh kèm banner lỗi, `/api/version` vẫn trả đúng SHA, CD/`evidence/M10.md` đều xanh | Bug production không ai biết cho tới khi có người mở tay một trang thật | Poll `/api/health` (quyết định B, cả staging lẫn production, không chỉ SHA) + cổng CI chặn prerender tĩnh (`ci.yml` job `frontend`, A3) |

## Gợi ý trả lời 3 câu tự kiểm tra (guide)

1. **Vì sao warm-up statuses chỉ nên là 200?** `be` trả 503 khi không ping được DB. Nếu 503 được
   coi là "đã phản hồi" thì swap đưa lên production một bản đang không nói chuyện được với DB.
   Rộng hơn nữa (vd để trống) thì cả 404 do path sai cũng qua (bẫy thứ 3 của guide).
2. **Sau swap, bản cũ nằm ở đâu, giữ bao lâu?** Ở slot staging, nguyên vẹn, cho tới lần CD kế tiếp
   đặt image mới vào staging. Đó là cửa sổ rollback nhanh (swap lại, vài chục giây, không build).
   Hết cửa sổ khi merge tiếp theo bắt đầu set image — nên rollback tự động chỉ trong cùng run.
3. **Vì sao bước xoá luật tạm phải chạy vô điều kiện?** Luật tạm là một lỗ trên whitelist M6. Job
   đỏ ở poll (C2, C3) chính là lúc hay bị bỏ quên nhất — nếu bước dọn chỉ chạy khi xanh thì mỗi lần
   deploy hỏng để lại một IP runner được phép vào cả 4 bề mặt (kể cả Kudu, vì
   `scm_use_main_ip_restriction = true`).

## Ước lượng

| Pha | Thời gian | Tốn tiền |
|---|---|---|
| A — code + PR + merge | ~3 giờ | không |
| B — `make up` + kiểm cấu hình | ~40 phút | có |
| C — 4 tình huống + 2 revert (≈ 6 run CD, mỗi run 7–12 phút) | ~1.5–2 giờ | có |
| D — ghi chép | ~45 phút (một phần song song với C) | có nếu làm lúc môi trường bật |
| E — `make down` | ~30 phút | có tới khi xong |

Môi trường bật ~3–4 giờ: P0v3 ~0.09 USD/giờ + MySQL B1ms ~0.03 USD/giờ + ACR Basic ~0.17 USD/ngày
(giá Retail API 15/09, xem plan mục Validation) → dưới 1 USD.

## Lưu ý cho phiên có AI

- Kế hoạch này do Claude Code viết (2026-09-24) — ghi vào `## AI usage` của PR D17.
- Đã kiểm bởi sub-agent review (2026-09-24): schema azurerm 4.81.0 — `sticky_settings` nằm ở
  web app (không ở slot), `health_check_eviction_time_in_min` **tuỳ chọn**, khoảng 2–10 chỉ Azure
  kiểm lúc apply; cờ `az webapp config access-restriction add/remove` đủ như bảng A4 (az local).
  Vẫn đọc `--help` lại khi viết — D16 có case AI dùng sai lệnh `az` mà chỉ `--help` mới lộ (#28).
- Khi hai slot khác `API_BASE_URL` (sticky), pha 1 của swap restart `fe` staging bằng
  `API_BASE_URL` của production → swap `fe` lâu hơn trước. Ghi số giây vào `notes/d17.md`; D18 cần.
- Nhận định "access restriction không đi theo swap" và "warm-up sai mã thì swap dừng" lấy từ docs
  App Service — kiểm bằng số đo ở Pha C, ghi kết quả thật vào `notes/d17.md`. Tên operation
  `slotsswap` trong lệnh activity-log ở C4 cũng vậy: chạy thử, nếu rỗng thì bỏ `--query` để xem
  tên thật.

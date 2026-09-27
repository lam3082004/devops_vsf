# D18 — Kế hoạch chi tiết: Bằng chứng zero-downtime (M2)

Guide gốc: `docs/guides/d18-zero-downtime.md` · Nhật ký: `notes/d18.md` (tạo khi làm) ·
Bằng chứng: `evidence/M2.md`, log thô `evidence/raw/m2-*.log`
Phiên trước: `notes/d17.md`, `notes/d17-prep.md` (4 quyết định A–D, Pha A code xong)

> **Điều kiện vào D18 — ĐÃ ĐẠT (2026-09-27):** D17 xong trọn (`notes/d17.md`): Terraform D17 đã
> apply trên `jcip0s`, C1–C4 chạy thật, 0 luật tạm sót, `plan` No changes, M6 8/8. Production lúc
> đóng D17: `be` + `fe` = `507710a`. Môi trường **đang bật** theo quyết định người dùng. B0 vẫn
> đọc lại trạng thái thật bằng `az` trước khi đo — tài liệu có thể trôi, số đo tại chỗ mới là căn cứ.
>
> **Mới từ D17, đọc trước khi viết script:** slot vừa đổi container có thể trả **403 / body lạ**
> trong ~1 phút (`known-issues.md` #20, chưa rõ nguồn) — lý do script phải lưu body (A1) và bẫy P12.

## Đọc 60 giây này trước

| | |
|---|---|
| **Tốn tiền?** | Viết/tự kiểm script (Pha A) **không**. Đo thật (Pha B/C) **có**, nhưng môi trường `jcip0s` **đang bật theo lựa chọn của người dùng** — D18 không cần `make up` riêng, chỉ cần xác nhận nó còn đúng cấu hình D17 (B0). Nhánh "nếu môi trường đã tắt" ở cuối Pha B. |
| **Làm gì** | (1) Viết `scripts/m2-poll.sh`: poll **cả hai** `be` `/version` và `fe` `/api/version` trên **production**, 1 lần/giây, cùng một vòng lặp, ghi log thô TSV — cả hai service, vì swap `be` rồi `fe` **không nguyên tử** nên có cửa sổ hai service lệch phiên bản, đó là điều phải **đo được**, không phải điều phải "sửa" · (2) chạy script bọc quanh một PR nhỏ merge → CD swap thật · (3) đọc log: đếm non-200 theo từng service, đo cửa sổ A→B · (4) `evidence/M2.md`. |
| **Ai chạy** | Mọi lệnh **kích hoạt CD thật** (merge PR, `gh workflow run cd.yml`, `gh pr merge`) đánh dấu **👤 người dùng chạy** — bộ lọc phiên này chặn AI tự trigger deploy/merge. AI chỉ viết script, đọc log, viết evidence. |
| **Xong khi** | 3 ô cuối guide: script trong repo · log thô 0 non-200 mỗi service + A→B · `evidence/M2.md`. |
| **Sau D18** | D19 (autoscale) — dùng `/load`, không liên quan swap nữa. |

## Quyết định phải chốt TRƯỚC khi viết script

Ghi câu trả lời vào `notes/d18.md` mục Decisions.

| # | Câu hỏi | Lựa chọn | Đề xuất |
|---|---|---|---|
| A | Poll từ đâu — máy nào phải nằm trong whitelist? | (a) máy nhà, IP thoát WARP `104.30.170.218` (đã whitelist, ổn định 6/6 lần đo) · (b) GitHub runner + luật tạm kiểu `cd.yml` | **Khuyến nghị (a).** Lý do: (1) quan sát **độc lập** với CD — nếu code poll/verify của chính `cd.yml` có bug, một máy ngoài vẫn bắt được, còn poll bằng runner vẫn chung hạ tầng GitHub Actions với pipeline deploy; (2) không cần thêm/gỡ access-restriction nào (chỉ đọc, không mutate Azure) — an toàn hơn, đúng tinh thần "M2 là quan sát, không phải một phần pipeline"; (3) mô phỏng đúng góc nhìn một người dùng thật ở đâu đó trên Internet. Giá phải trả: WARP là tầng mạng riêng của máy này — hiccup ở đó tạo ra non-200 **giả** phía client, phải tách `curl_exit`/`time_total` ra khỏi mã HTTP để không đổ oan cho swap (xem quyết định C và Bảng bẫy P3/P4) |
| B | Poll cả hai service trong 1 vòng lặp, hay 2 script song song? | (a) một script, mỗi tick gọi tuần tự be rồi fe (hoặc song song bằng subshell), ghi chung 1 file · (b) hai script riêng, hai file | **Khuyến nghị (a).** Guide D18 gốc chỉ nói "poll `/version`" — số ít, viết cho một service. Nhưng M10/D16 đã chứng minh swap `be` và `fe` lệch nhau tới hơn trăm giây (`evidence/M10.md`), nên "zero-downtime" của **hệ hai service** phải đọc được cả hai cùng lúc, cùng một đồng hồ tick, để so được đúng thời điểm — hai file riêng dễ lệch mili-giây giữa hai tiến trình, khó ghép lại khi phân tích |
| C | "Non-200" tính thế nào khi có timeout/lỗi mạng phía client (không phải server)? | (a) gộp timeout/curl lỗi vào cùng cột non-200 · (b) tách riêng cột `curl_exit`, chỉ tính "server non-200" khi curl thành công (`exit=0`) nhưng mã HTTP ≠ 200 | **(b), nhưng KHÔNG lặng lẽ loại bỏ.** Guide gốc nói thẳng: "timeout ghi là lỗi". Vẫn đúng — với người dùng thật, timeout CHÍNH LÀ downtime, không quan trọng do server hay do mạng. Cách hoà giải: log đủ 2 cột (`http_code`, `curl_exit`), tóm tắt báo **cả hai số** ("N request server non-200" và "M request client lỗi/timeout"), evidence/M2.md giải thích riêng từng loại — không được cộng gộp thành một con số "0 non-200" nếu thực ra là 3 lần WARP hiccup, cũng không được xoá 3 lần đó khỏi log |
| D | Có poll thêm trang thật (`fe` `/`) như bài học #18 không? | (a) chỉ poll đúng 2 route `/version` theo guide · (b) thêm cột thứ 3, poll `fe` `/` (chỉ mã HTTP, không đọc nội dung) | **(b), nhưng chỉ tham khảo, không tính vào tiêu chí "0 non-200" của M2.** `#18` cho thấy trang có thể trả 200 kèm banner lỗi — poll mã HTTP của `/` không bắt được lỗi *đó* (đã có cổng CI + `/api/health` của D17 lo phần này). Thêm cột này rẻ (một `curl` nữa mỗi giây) và là lưới phụ nếu `/` bắt đầu trả 5xx/000 mà `/api/version` vẫn 200 (hai route có thể có hành vi cache/route khác nhau) |
| E | Kết nối HTTP: mỗi request một kết nối mới, hay giữ keep-alive? | (a) mỗi lần gọi `curl` là một tiến trình mới → TCP+TLS mới mỗi giây · (b) một kết nối giữ xuyên suốt (`curl --next` nhiều URL trong 1 lần gọi, hoặc HTTP/1.1 keep-alive qua cùng handle) | **(a) làm chính.** Thực tế nhiều người dùng khác nhau = nhiều kết nối khác nhau, đúng với điều swap phải chịu được (App Service phải route đúng dù là kết nối mới). (b) — tối ưu (đo phiên bản variant) làm **tuỳ chọn**, không bắt buộc: một kết nối giữ nguyên qua lúc swap có thể lộ ra một lớp lỗi khác (kết nối bị cắt giữa chừng khi instance cũ bị dừng) mà (a) không thấy, đáng ghi là hạn chế của lần đo (a) trong `evidence/M2.md`, không phải phải làm ngay |

## Hiểu trước khi làm — 5 điều quyết định thiết kế

1. **M2 không phải một phần của `cd.yml`.** Vòng kiểm production N=5 lần trong job `swap`
   (`notes/d17.md` mục A4) phục vụ mục đích khác: quyết định có cần rollback hay không, chạy rời
   rạc 5s/lần, và chạy **từ trong** pipeline (không phải quan sát độc lập). M2 cần một quan sát
   viên **ngoài** CD, tick dày hơn (1s), chạy suốt từ trước lúc merge tới sau khi swap xong —
   không thể lấy log của `cd.yml` làm bằng chứng M2, dù cả hai đều gọi cùng URL.
2. **"Zero-downtime" với hai service nghĩa là: mỗi service riêng lẻ 0 non-200 — không phải cả hệ
   thống lúc nào cũng đồng bộ SHA.** Vì Azure không có API swap nhiều app một lượt (đã ghi trong
   `cd.yml`/`notes/d17.md`), giữa lúc `be` đã đổi và `fe` chưa đổi (hoặc ngược lại xét theo phiên
   bản cache trình duyệt), có một cửa sổ observable "hai service không cùng thế hệ". Đó là hành
   vi **đúng và có chủ ý** (thứ tự `be` trước `fe`, lý do đã ghi ở D17) — nhiệm vụ của D18 là **đo
   và báo cáo độ dài cửa sổ đó**, không phải chứng minh nó bằng 0.
3. **Whitelist chỉ có đúng 1 IP hợp lệ, và nó là IP thoát WARP — lớp hạ tầng lịch sử đã từng gây
   lỗi.** `known-issues.md` #19 ghi lại: IP thoát WARP từng bị coi là "dải anycast dùng chung,
   không phải IP nhà", và `evidence/M10.md` (mục D16, 24/09 14:50) nghi ngờ chính dải này là
   nguồn gốc một lần 403 bất chợt. Việc "ổn định 6/6 lần đo" của phiên này là **một điểm dữ liệu
   tốt, không phải một chứng minh** — D18 phải tự đo lại (không tin lại con số cũ) trước và sau
   khi chạy, style triết lý D13 "IP nhà không phải một số mà là hai" (#11): đo một lần không đủ.
4. **Cột `curl_exit`/`time_total` không phải để trang trí log — nó là công cụ chẩn đoán khi có
   non-200.** 403 (đổi IP whitelist giữa chừng) và 000/timeout (WARP hiccup phía client) và
   502/503 (nền tảng Azure lúc swap) đều làm dòng log "xấu" như nhau nếu chỉ nhìn `http_code`,
   nhưng nguyên nhân và người chịu trách nhiệm hoàn toàn khác nhau. Guide mục 4 ("Nếu có lỗi") đã
   liệt kê đúng phân loại này — script phải ghi đủ dữ liệu để tra được, không chỉ đếm.
5. **Script phải sống sót qua Ctrl+C và qua lỗi từng request** — không được có `set -e` trong
   vòng lặp poll (đúng bẫy P4 đã trả giá ở D17), và phải in được tóm tắt ngay cả khi bị ngắt giữa
   chừng (trap `SIGINT`/`SIGTERM` của chính script, khác với graceful shutdown SIGTERM của app —
   đừng nhầm hai tầng SIGTERM này khi đọc `Program.cs`).

---

## Pha A — Viết script (KHÔNG tốn tiền) · ~1.5 giờ

Nhánh: `git fetch && git switch -c chore/d18-m2-poll origin/main` (tên nhánh `chore/` — chỉ thêm
công cụ đo, không đổi hành vi app/infra).

### A1. Đặc tả `scripts/m2-poll.sh`

- [ ] Tham số dòng lệnh: `--be-url`, `--fe-url` (bắt buộc, ví dụ
      `https://app-vsf-jcip0s.azurewebsites.net`), `--out` (mặc định
      `evidence/raw/m2-$(date -u +%Y%m%d-%H%M%S).log`), `--duration` (giây, tuỳ chọn — không đặt
      thì chạy tới khi Ctrl+C), `--extra-fe-page` (tuỳ chọn, quyết định D — mặc định `/`)
- [ ] Mỗi tick (1 giây), với **mỗi** service (`be`, `fe`, và tuỳ chọn `fe-page`):
      1 lệnh `curl -4 -s --max-time 3 -w $'\n%{http_code}\n%{time_total}'` (đúng idiom đã dùng
      trong `cd.yml`/`m6-check.yml` — body + code + thời gian trong **một** lần gọi, không gọi
      `curl` hai lần cho cùng một service như từng thấy ở `m6-check.yml`), bắt riêng `$?` ngay
      sau lệnh (**trước** khi chạm vào `|| true`/`|| echo` nào) làm `curl_exit`
- [ ] Parse: 2 dòng cuối của output là `http_code` và `time_total`, phần còn lại là `body`. Body
      rỗng hoặc không parse được JSON → `sha=-` (không phải rỗng chuỗi, để cột TSV không lệch).
      `jq -r '.sha // empty'` như `cd.yml` đã dùng — tái dùng đúng cách đọc đã có trong repo,
      không phát minh cách khác
- [ ] Cột file log (TSV, 1 dòng header, UTC — **không** dùng `+07:00` như ví dụ minh hoạ trong
      guide gốc: log thô cần đối chiếu thẳng với Activity Log Azure và `cd.yml`, cả hai đều UTC,
      lệch múi giờ ở bước đọc chỉ tổ dễ sai một lần cộng trừ tay):
      ```
      ts_utc_ms	svc	http_code	sha	curl_exit	time_total_s
      2026-09-26T09:15:03.041Z	be	200	9d4e160...	0	0.087
      2026-09-26T09:15:03.052Z	fe	200	9d4e160...	0	0.091
      ```
      `svc` ∈ `{be, fe, fe-page}`. Mỗi tick ghi 2 (hoặc 3, quyết định D) dòng, gọi be/fe **song
      song** (subshell + `wait`, không tuần tự) để độ trễ của service này không cộng dồn vào
      tick của service kia và làm lệch nhịp 1s
- [ ] Vừa in ra màn hình (rút gọn: `svc code sha8 exit t` một dòng) vừa ghi file — giữ đúng yêu
      cầu "vừa in vừa ghi" của guide
- [ ] **Mọi response có mã ≠ 200 (hoặc 200 mà không parse được `sha`): lưu 300 byte đầu của body**
      vào file phụ `<out>.bodies` (dòng: `ts svc code <body một dòng>`). Lý do: D17 thấy slot
      staging trả **403 / body lạ** ~1 phút sau khi đặt image mới (`known-issues.md` #20) mà
      `cd.yml` không in body nên không tra được nguồn. Nếu M2 thấy non-200 lúc swap, body là thứ
      duy nhất phân biệt 403 của nền tảng (trang HTML Azure) với 403 của whitelist hay 5xx của app
- [ ] Bắt `SIGINT`/`SIGTERM` (trap): dừng vòng lặp, in **tóm tắt** ra cả màn hình lẫn cuối file
      log (dạng comment `#` để không phá TSV khi `awk`/`cut` đọc lại), rồi `exit 0`. Tóm tắt gồm:
      tổng số tick mỗi service, số "server non-200" (curl_exit=0 và code≠200) tách riêng số
      "client lỗi" (curl_exit≠0 hoặc code=000), SHA đã thấy theo thứ tự xuất hiện mỗi service,
      timestamp **cuối cùng** thấy SHA cũ và **đầu tiên** thấy SHA mới mỗi service, độ dài cửa sổ
      hai service lệch SHA (nếu có)
- [ ] KHÔNG `set -e` trong vòng lặp chính (chỉ `set -uo pipefail`, đúng bẫy P4 của D17 lặp lại)
- [ ] Không phụ thuộc gì ngoài `curl`, `jq`, `date`, `awk`/`bash` có sẵn trên máy — đúng yêu cầu
      "không phụ thuộc" của guide

### A2. Kiểm khô (không chạm Azure)

- [ ] Dựng một server giả cục bộ (`python3 -m http.server`, hoặc script `nc`/`socat` trả JSON cố
      định) trả `{"sha":"aaa"}` liên tục 20 giây rồi đổi sang `{"sha":"bbb"}` — chạy
      `m2-poll.sh --be-url http://127.0.0.1:8001 --fe-url http://127.0.0.1:8002 --duration 40`,
      kiểm log ra đúng 2×40 dòng, đúng thời điểm chuyển A→B, cột `curl_exit`/`time_total` hợp lý
- [ ] Test riêng: tắt server giả 5 giây giữa chừng (mô phỏng downtime/timeout thật) → xác nhận
      dòng log tương ứng có `http_code=000`, `curl_exit≠0`, **và** vòng lặp KHÔNG chết (bẫy P4)
- [ ] Ctrl+C giữa chừng → xác nhận tóm tắt in đúng, file log có đủ dòng tới thời điểm ngắt
- [ ] `shellcheck scripts/m2-poll.sh` (nếu có sẵn trên máy) hoặc đọc tay theo 3 điểm A5 của
      `notes/d17-prep.md` (không `set -e` trong vòng lặp, dọn/tóm tắt không phụ thuộc bước có thể
      chưa chạy, không in secret — script này không có secret nào để in)

### A3. PR → CI → merge (KHÔNG tốn tiền — script chỉ đọc HTTP công khai)

- [ ] PR có mục `## AI usage` (script do AI viết — ghi rõ, theo luật `CLAUDE.md`: từ D7 được
      sinh code, mỗi PR phải khai)
- [ ] CI xanh (script mới không chạm Terraform/`cd.yml`/app — job `terraform plan` vẫn chạy vì
      luôn chạy, nhưng phải ra không gì đổi ngoài phạm vi `scripts/`)
- [ ] ⚠️ **Merge PR này KÍCH HOẠT CD** — `cd.yml` chạy theo mọi push vào `main`, không có path
      filter, nên kể cả PR chỉ thêm script cũng build + push + swap thật (SHA đổi dù code app không
      đổi). **Đề xuất: dùng chính lần merge này làm lần đo M2 đầu tiên** — chạy script (Pha C2)
      TRƯỚC khi 👤 người dùng bấm merge. Như vậy không cần PR "thay đổi nhỏ" riêng; PR thứ hai
      (Pha C1) chỉ cần cho lần đo lặp lại

---

## Pha B — Xác nhận môi trường & whitelist (TỐN TIỀN — môi trường đã bật sẵn, không cần `make up`)

- [ ] **B0. BẮT BUỘC, đọc trước khi tin phần "Facts" ở đầu file này.** Xác nhận D17 Pha B/C đã
      thật sự chạy, bằng đúng lệnh của `notes/d17-prep.md` B4/B5:
      ```bash
      BE=$(az webapp list -g rg-vsf-dev --query "[?starts_with(name,'app-vsf-')].name" -o tsv)
      FE=$(az webapp list -g rg-vsf-dev --query "[?starts_with(name,'fe-vsf-')].name" -o tsv)
      for A in $BE $FE; do for S in "" "--slot staging"; do
        az webapp config show -g rg-vsf-dev -n $A $S --query "{hc:healthCheckPath, alwaysOn:alwaysOn}" -o tsv
      done; done
      terraform -chdir=infra/app plan -lock=false   # mong đợi: No changes
      ```
      Nếu bất kỳ `hc` nào sai path, hoặc `plan` ra khác "No changes" → **dừng, quay lại D17**,
      đừng đo M2 trên hạ tầng chưa đúng (giá trị của số đo phụ thuộc chính vào cơ chế D17)
- [ ] **B1.** Đo IP thoát máy hiện tại — **không tin lại con số cũ dù đã có "6/6 lần"**:
      ```bash
      for i in $(seq 1 15); do curl -4 -s --max-time 5 https://api.ipify.org; echo; sleep 1; done
      ```
      Mong đợi: 15/15 ra đúng `104.30.170.218`. Khác đi dù chỉ 1 lần → whitelist hiện tại
      (`terraform.tfvars`) không còn khớp, phải đo lại theo đúng quy trình #19/#11 trước khi tiếp
- [ ] **B2.** Ghi SHA hiện tại (baseline, "A") của cả hai service:
      ```bash
      curl -4 -s https://$BE.azurewebsites.net/version
      curl -4 -s https://$FE.azurewebsites.net/api/version
      ```
- [ ] **B3.** Nếu môi trường **đã tắt** khi bắt đầu phiên này (nhánh dự phòng, không phải trạng
      thái hiện tại): ⚠️ xác nhận trước (tốn tiền) → `make up` → đợi `Apply complete` → lặp lại
      B0–B2 trước khi sang Pha C

---

## Pha C — Chạy đo (TỐN TIỀN — swap thật) · ~45 phút/lần, cần ít nhất 1, tốt nhất 2 lần

Mỗi lần chạy: theo đúng thứ tự quy trình của guide gốc (mục 2), điều chỉnh cho hai service.

### C1. Chuẩn bị commit tạo swap thật

- [ ] Việc merge PR ở Pha A3 **đã** tạo một swap — nếu chưa merge, dùng chính PR đó; nếu đã merge
      rồi mới đọc tới đây, mở một PR nhỏ khác (đổi 1 dòng comment vô hại, ví dụ trong
      `README.md`) để có một swap sạch canh đúng lúc script đang chạy. **Không** dùng lại cách
      "revert" của D17 C2/C3 (những PR đó cố ý gây lỗi) — D18 cần một swap **thành công bình
      thường** để đo, không phải một tình huống lỗi
- [ ] CI của PR đó phải xanh **trước** khi bắt đầu script (không muốn vừa chạy poll vừa chờ CI)

### C2. Chạy script + kích hoạt CD

- [ ] `mkdir -p evidence/raw`
- [ ] Bắt đầu script (chạy nền hoặc terminal riêng, KHÔNG timeout để lỡ mất cửa sổ swap):
      ```bash
      scripts/m2-poll.sh --be-url https://$BE.azurewebsites.net \
        --fe-url https://$FE.azurewebsites.net \
        --out evidence/raw/m2-$(date -u +%Y%m%d-%H%M%S).log
      ```
- [ ] Đợi **60 giây baseline** (script chạy, chưa merge gì) — xác nhận log toàn 200, toàn SHA A
- [ ] 👤 **Người dùng chạy**: merge PR chuẩn bị ở C1 (qua GitHub UI hoặc `gh pr merge --squash`)
- [ ] Theo dõi CD (`gh run list -w CD -L 1` rồi `gh run view <id>` — AI được phép **đọc** trạng
      thái run, chỉ không được là người **bấm** merge/dispatch)
- [ ] Sau khi job `swap` của CD báo xanh (hoặc rollback nếu C4 tuỳ chọn) → để script chạy thêm
      **≥ 2 phút** nữa (đúng yêu cầu guide) rồi Ctrl+C
- [ ] Đọc tóm tắt vừa in ra, dán tạm vào `notes/d18.md`

### C3. Đọc log — tiêu chí ĐẠT

| Quan sát | Nghĩa |
|---|---|
| `be`: 0 server non-200, SHA A…A → B…B; `fe`: 0 server non-200, SHA A…A → B…B | ✅ đạt cho cả hai service |
| Vài dòng A/B xen kẽ **trong cùng một service** quanh lúc swap | bình thường (nhiều instance/kết nối cũ, câu tự kiểm tra #3) — vẫn đạt nếu 0 non-200 |
| `be` đã đổi B nhưng `fe` còn A (hoặc ngược lại) trong X giây | **bình thường và mong đợi** (điều 2 ở "Hiểu trước khi làm") — ghi độ dài X vào `evidence/M2.md`, KHÔNG coi là lỗi |
| Có server 5xx/000 với `curl_exit=0` quanh lúc swap | chưa đạt → mục C4/guide mục 4 |
| `curl_exit≠0` rải rác, không tập trung quanh lúc swap | nghi WARP hiccup, không phải swap — đối chiếu B1 (đo IP lại ngay) |
| Không bao giờ thấy B | CD chưa swap thật / cache CDN / nhầm URL — kiểm `gh run view` trước khi nghi script |

### C4. Nếu có server non-200 thật (curl_exit=0, code≥400)

Theo đúng bảng "Nếu có lỗi" của guide, cộng thêm phân biệt bằng `curl_exit`:

| Triệu chứng | Hướng tìm |
|---|---|
| 503 ngay lúc swap | warm-up path/statuses (D17) chưa đủ — đọc lại `WEBSITE_SWAP_WARMUP_PING_STATUSES` |
| 502/000 vài giây sau swap, `curl_exit≠0` xen 000 thật | instance cũ bị dừng khi còn request — tắt êm SIGTERM (`Program.cs` `ApplicationStopping`, đã có từ D4 — nếu vẫn thấy, đo `ShutdownTimeout` có đủ dài hơn thời gian xử lý request đang chạy dở không) |
| 403 | **IP máy đổi giữa chừng** (không phải lỗi swap) — B1 phải phát hiện được nếu đo lại ngay; xem Activity Log xem có ai `terraform apply`/sửa `access-restriction` trùng lúc không (bẫy P8 của D17) |
| Lỗi khi instance restart | thời gian khởi động container — đối chiếu `WEBSITES_CONTAINER_START_TIME_LIMIT` (D17 quyết định D, "để mặc định" — nếu chưa có số đo thật thì đây là dịp đo) |

Sửa → PR → chạy lại **toàn bộ Pha C** → giữ **cả log thất bại** (không xoá, ghi vào
`evidence/M2.md` phần "lần thử trước", đúng nguyên tắc guide mục 4).

### C5. (Tuỳ chọn) Đo lúc rollback cũng zero-downtime

- [ ] ⚠️ Xác nhận trước. 👤 **Người dùng chạy**:
      `gh workflow run cd.yml --ref main -f simulate_verify_failure=true`
- [ ] Script chạy y hệt C2 quanh run này. Log mong đợi: `be`/`fe` đổi sang B (swap xong), rồi
      **đổi lại** về A (rollback, `fe` trước rồi `be` — đúng thứ tự D17) — **hai** cửa sổ chuyển
      SHA trong cùng một lần chạy script, không phải một
- [ ] Đánh dấu rõ trong `evidence/M2.md`: đây là run **tuỳ chọn**, không phải điều kiện "Xong
      khi" của guide D18 — chỉ làm nếu còn thời gian

---

## Pha D — Ghi chép (không tốn tiền thêm)

- [ ] `notes/d18.md`: 5 quyết định A–E, link run CD, số liệu tóm tắt từng lần chạy, thứ gì kế
      hoạch này nói sai
- [ ] `evidence/M2.md` — cấu trúc bắt buộc:
      - Link script (`scripts/m2-poll.sh`), link PR, link run CD, thời điểm bắt đầu/kết thúc swap
        (đối chiếu Activity Log như C4 hoặc log job summary của `cd.yml`)
      - Bảng các lần chạy: | # | non-200 be | non-200 fe | client-lỗi (curl_exit≠0) | A→B be (từ→đến) | A→B fe (từ→đến) | cửa sổ hai service lệch SHA |
      - Trích 15–20 dòng log thô quanh đúng thời điểm chuyển A→B (cả be lẫn fe interleave)
      - Giải thích cửa sổ lệch SHA hai service bằng số đo thật (không chỉ lý thuyết ở điều 2)
      - Đường dẫn đầy đủ file log thô, ghi rõ **không chỉnh sửa**
      - Nếu có non-200 ở lần đầu: mục "lần thử trước" + đã sửa gì
- [ ] `known-issues.md`: cập nhật mục 3 ("Chưa xong" — CD + zero-downtime, D16–D18) sang đã đo,
      hoặc thêm mục mới nếu vẫn còn hở
- [ ] `ai-failure-log.md`: nếu script hoặc phân tích log có chỗ AI sinh sai (script mới, nhiều khả
      năng có ít nhất 1 case — vd double `000000` như đã từng thấy ở `cd.yml`/`m6-check.yml`)
- [ ] Plan `docs/plans/active/azure-app-service-internship.md`: tick D18 + 1 dòng Recovery —
      đừng để plan và `notes/d18.md` lệch nhau cho phiên sau đọc nhầm

---

## Pha E — Cuối phiên (môi trường KHÔNG tắt theo lựa chọn của người dùng)

- [ ] Không chạy `make down` — người dùng đã quyết định giữ `jcip0s` bật. Chỉ **nhắc chi phí**
      (luật project: "cuối phiên nhắc `make down` nếu môi trường đang bật"), không tự ý tắt:
      P0v3 ~0.09 USD/giờ + MySQL B1ms ~0.03 USD/giờ + ACR Basic ~0.17 USD/ngày — môi trường đã
      bật từ trước D18, D18 chỉ cộng thêm vài phút CD (build+push+swap, không phải phí riêng) và
      thời gian chạy script (chạy trên máy, không tính phí Azure)
- [ ] Không còn run CD nào `in_progress`: `gh run list -w CD -L 3` — kiểm trước khi rời phiên, dù
      không tắt môi trường (tránh Pha C bỏ dở giữa poll/swap)

---

## Bảng bẫy

| # | Bẫy | Hậu quả | Tránh |
|---|---|---|---|
| P1 | `set -e` trong vòng lặp poll | một `curl`/`jq` lỗi giết cả vòng lặp, mất hết log sau đó | Chỉ `set -uo pipefail`; mọi lệnh trong tick tự chịu lỗi |
| P2 | Gọi `curl -w '%{http_code}' ... \|\| echo "000"` — bẫy đã biết trong `cd.yml`/`m6-check.yml` | in ra `"000000"` (curl tự in `000` qua `-w` RỒI `\|\|` in thêm) khi mất kết nối hẳn — log xấu, dễ đọc nhầm mã HTTP | Dùng `\|\| true` (không `echo`), hoặc kiểm biến rỗng rồi tự gán `000` một lần |
| P3 | Coi mọi non-200 là do swap | WARP hiccup phía client (không liên quan Azure) bị tính nhầm thành lỗi swap, hoặc ngược lại một lỗi swap thật bị đổ cho "chắc do mạng nhà" mà không kiểm tra | Luôn có cột `curl_exit` riêng; đối chiếu thời điểm non-200 với B1 (đo IP lại) và Activity Log trước khi kết luận |
| P4 | IP thoát WARP đổi **giữa lúc** đang chạy script (đã từng nghi ở D16/#19 — dải anycast) | một loạt 403 giữa chừng, dễ nhầm là "swap chặn truy cập" | Đo IP lại (B1-style) NGAY sau khi thấy 403 kéo dài, trước khi nghi app; ghi cả hai lần đo (trước/sau) vào evidence |
| P5 | Hai vòng poll `be`/`fe` chạy 2 tiến trình riêng, ghi 2 file | log lệch tick, khó ghép để tính cửa sổ hai service lệch SHA chính xác | Một script, một vòng lặp, ghi chung 1 file (quyết định B) |
| P6 | `--max-time` quá ngắn (< 1s) | timeout giả trong khi server chỉ chậm nhẹ lúc cold-start/health ping — tính nhầm thành non-200 | Theo guide: 2–3 giây |
| P7 | Coi cửa sổ A/B xen kẽ (một service, nhiều instance) hoặc cửa sổ be≠fe (hai service) là "chưa đạt" rồi cố "sửa" nó | Sửa nhầm thứ đang hoạt động đúng thiết kế — mất thời gian, có thể phá code D17 đang đúng | Đọc lại "Hiểu trước khi làm" điều 2 + guide mục 3 trước khi kết luận có lỗi |
| P8 | Mở PR/kích hoạt CD mới trong khi script + CD của lần chạy trước chưa xong | Hai swap chồng lên nhau trong cùng file log, khó tách bạch bằng chứng của từng lần chạy (giống P10 ở `notes/d17-prep.md`) | Làm tuần tự: đợi Ctrl+C + lưu tóm tắt xong mới mở PR tiếp |
| P9 | AI tự chạy `gh pr merge`/`gh workflow run cd.yml` | Vi phạm luật "tốn tiền = hỏi trước" và bộ lọc phiên này chặn AI trigger deploy | Mọi lệnh loại này đánh dấu 👤 người dùng chạy, AI chỉ chuẩn bị PR và đọc kết quả |
| P10 | Tin số đo "IP ổn định 6/6 lần" của phiên trước mà không đo lại | Nếu whitelist thật ra đã đổi (như từng thấy ở #11, #19) thì cả log sẽ đầy 403 và bị hiểu nhầm thành lỗi swap | B0/B1 luôn đo lại tại chỗ, không dùng số cũ |
| P12 | 403 **tạm thời** trên slot vừa đổi container — đã thấy ở D17 C1/C2r/C3 trên **staging** (`known-issues.md` #20, chưa rõ nguồn) | Nếu cùng hiện tượng xảy ra ở production lúc swap: M2 thấy vài 403 và dễ đổ nhầm cho whitelist (P4) | Đọc file `.bodies` (A1): trang HTML nền tảng ≠ trang 403 whitelist; đối chiếu thời điểm với activity log swap. Có 403 kiểu này thì M2 **chưa đạt**, phải ghi thật, không loại khỏi log |
| P11 | Đọc log tóm tắt của script rồi coi đó là `evidence/M2.md` | Tóm tắt do script tự in không có ngữ cảnh (link PR/run, giải thích cửa sổ lệch SHA) mà đề bài yêu cầu | Pha D viết `evidence/M2.md` tay, dùng tóm tắt script làm **nguyên liệu**, không phải bản nộp |

## Gợi ý trả lời 3 câu tự kiểm tra (guide)

1. **Vì sao timeout phải tính là lỗi?** Với người dùng thật đang gọi app, một request không có
   phản hồi trong thời gian chấp nhận được **chính là** downtime cảm nhận được — không quan
   trọng nguyên nhân là server treo hay gói tin rớt giữa đường. Guide đúng khi bắt ghi `status=000`
   là lỗi. Nhưng quyết định C của kế hoạch này thêm một lớp: vẫn ghi là lỗi, **và** ghi kèm
   `curl_exit` để sau này phân biệt được lỗi đó có phải do swap hay không, thay vì phải đoán.
2. **Log thô có giá trị hơn screenshot ở điểm nào?** Ảnh chụp chỉ chứng minh một thời điểm; log
   thô có dấu thời gian từng dòng nên chứng minh được tính **liên tục** (đúng 1 request/giây suốt
   cửa sổ swap, không có khoảng trống nào không quan sát), đếm được chính xác bằng công cụ
   (`awk`/`grep`) thay vì đếm mắt trên ảnh, và tái phân tích được nếu sau này cần tính lại theo
   tiêu chí khác (ví dụ tách `curl_exit` như D18 làm thêm) — ảnh chụp thì cố định, không tính lại
   được.
3. **Nếu 2 instance đang chạy khi swap, log sẽ trông khác thế nào?** Load balancer nền tảng có
   thể route round-robin giữa các instance chưa đồng bộ swap cùng lúc — vài request liên tiếp
   quanh thời điểm swap có thể xen kẽ SHA cũ/mới (một instance đã nhận bản mới, instance kia
   chưa) trước khi tất cả hội tụ về cùng một SHA. Bình thường, miễn 0 non-200 — guide đã nói rõ ở
   mục 3. Ở D18 plan đang `worker_count = 1` (`infra/app/app.tf`) và **chưa có autoscale** (D19
   mới dựng, max 2) — nên lần đo này chỉ có 1 instance, xen kẽ SHA (nếu thấy) đến từ kết nối cũ
   lúc chuyển định tuyến, không phải từ 2 instance. Ghi rõ hạn chế này trong `evidence/M2.md`; có
   thể đo lại M2 sau D19 khi có 2 instance.

## Ước lượng

| Pha | Thời gian | Tốn tiền |
|---|---|---|
| A — viết + kiểm khô script | ~1.5 giờ | không |
| B — xác nhận D17 + IP whitelist | ~20 phút | môi trường đã bật sẵn, không cộng thêm |
| C — 1–2 lần chạy đo (+ tuỳ chọn rollback) | ~45 phút/lần | có (mỗi lần = 1 run CD ~7–10 phút build+push+swap) |
| D — ghi chép | ~1 giờ | không (môi trường vẫn bật nhưng D18 không cần Azure nữa lúc viết) |
| E — nhắc chi phí, không tắt | ~5 phút | môi trường tiếp tục tính tiền theo lựa chọn của người dùng |

Không có `make up`/`make down` riêng cho D18 (môi trường đã bật) → chi phí phát sinh **thêm** so
với việc không làm D18 gần như chỉ là 1–3 run CD (build+push+swap, vài phút compute mỗi lần) +
thời gian môi trường bật kéo dài thêm để làm Pha C/D — nằm trong cùng ngân sách giờ đã tính ở
`notes/d17-prep.md` (P0v3 ~0.09 USD/giờ + MySQL B1ms ~0.03 USD/giờ + ACR Basic ~0.17 USD/ngày).

## Lưu ý cho phiên có AI

- Kế hoạch này do Claude Code viết (2026-09-26), DOCS ONLY — không sinh Terraform/`az`/YAML nào
  trong phiên viết kế hoạch. `scripts/m2-poll.sh` (Pha A) sẽ do AI sinh ở phiên **thực thi** D18 —
  PR của nó phải có mục `## AI usage`, đúng luật `CLAUDE.md` (từ D7 được sinh code).
- Bản nháp do sub-agent (Sonnet) viết, Opus review và sửa 4 chỗ: callout "mâu thuẫn D17" (thật ra
  chỉ là `notes/d17.md` chưa cập nhật kết quả apply 26/09 — đã cập nhật cùng PR) · A3 nói merge
  "không kích hoạt CD" (sai: không có path filter) · câu tự kiểm tra #3 giả định autoscale đã có
  (chưa, `worker_count = 1`) · xác nhận `Program.cs` có `ShutdownTimeout` + `ApplicationStopping`.
- `cd.yml` hiện tại đã có sẵn đúng idiom `curl -w $'\n%{http_code}'` (một lệnh, nhiều giá trị) và
  bài học "double 000000" — A1 tái dùng nguyên các cách đọc đó thay vì để AI phát minh lại và lặp
  lại đúng lỗi đã từng sửa.
- Session hiện tại có bộ lọc chặn AI tự trigger deploy/merge — mọi bước ở Pha C có gắn 👤 phải để
  người dùng tự chạy; đừng cố "giúp" bằng cách chạy hộ, kể cả khi có quyền kỹ thuật để làm việc đó.

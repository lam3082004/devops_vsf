# Bàn giao phiên 2026-09-23 — D13 xong, D14 sẵn sàng

Đọc file này trước khi mở phiên mới. Kế hoạch bài tiếp: `notes/d14-prep.md`.
Nhật ký phiên này: `notes/d13.md` · Bằng chứng: `evidence/M6.md`.

## Dán vào phiên mới

```
Tôi làm tiếp D14 (CI đầy đủ + bằng chứng đỏ, M9) của repo devops_vsf.

Đọc trước: notes/handoff-d13.md, notes/d14-prep.md, docs/guides/d14-ci-extended.md.

Bối cảnh: D1–D13 xong. Azure ĐANG TẮT (chỉ còn rg-vsf-bootstrap) và D14 KHÔNG cần
bật lại — toàn bộ bài chạy trên GitHub Actions + máy local, không tốn tiền.
Worktree sạch dùng lại được: .claude/worktrees/d12.

Ba điều đã biết trước, đừng làm lại: (1) ci.yml đã có 6 job, thiếu đúng docker-build
và trivy; (2) Q4 (chính sách Trivy) vẫn CHƯA chốt và đang chặn D14 — phải quét thật
app/be và app/fe lấy số trước rồi mới chọn chính sách; (3) required checks trong
ruleset protect-main có thể vẫn ghi tên job đã chết là "rust (fmt, clippy, test)" —
phải mở Settings đọc và xác minh, đừng đoán.

Luật project: không push main, mọi thay đổi qua PR; lệnh tốn tiền phải hỏi tôi trước;
cuối phiên bắt buộc make down nếu có bật môi trường.
```

## Trạng thái

- `main` = **PR #31 đã merge** (xem `git log origin/main -1`). PR #30 và #31 đều squash merge.
- **Azure trống.** `Destroy complete! Resources: 49 destroyed` lúc 12:17, `rg-vsf-dev`
  không còn tồn tại (`make check-empty` xác nhận). Chỉ còn `rg-vsf-bootstrap` (state) và
  hai `DefaultResourceGroup-*` của Azure Monitor (miễn phí, có từ trước).
- Không còn việc git nào treo. Worktree: `.claude/worktrees/d12`.
- **Cloudflare WARP:** tôi đã tắt lúc cuối phiên. Nó **tự bật lại** ít nhất một lần giữa
  phiên — nếu thấy `curl -4 https://ifconfig.me` ra `104.28.x.x` thì WARP đang bật.

## D13 — ĐẠT

M6 đạt đủ 4 ô "Xong khi" của guide. Bốn bề mặt × ba nguồn IP:

| Nguồn | site chính | slot | SCM | SCM slot |
|---|---|---|---|---|
| Máy làm việc (IP đã allow) | 200 | 200 | 200 (token) | 200 (token) |
| Runner GitHub `134.33.77.40` | 403 | 403 | 403 | 403 |
| Cloudflare WARP `104.28.xxx.xxx` | 403 | 403 | 403 (token) | 403 (token) |

Hoãn: 3 ảnh Portal của M6 (môi trường đã tắt). Gộp với **3 ảnh còn nợ của D12** —
env vars production + slot, log stream, MySQL networking — vào **một** phiên có môi
trường bật. Không chặn D14.

## Ba phát hiện đáng nhớ nhất

### 1. `scm_use_main_ip_restriction = true` KHÔNG khoá được Kudu

Nó chỉ copy **danh sách luật** của site chính, **không** kéo theo hành động mặc định —
`scmIpSecurityRestrictionsDefaultAction` vẫn là `Allow`, nên IP không khớp luật nào rơi
xuống Allow và **vào được Kudu**. Cùng một IP ngoài whitelist, cùng thời điểm: site chính
403 còn SCM trả **200** với token ARM.

Phải khai **ba** dòng chứ không phải hai:
`ip_restriction_default_action` + `scm_use_main_ip_restriction` + **`scm_ip_restriction_default_action`**.

**Suýt bỏ lọt** vì `curl` không xác thực vào Kudu luôn trả **401** dù chặn hay không — và
guide còn ghi "401 là đạt" (mục 3.2). Chỉ khi gọi **có token ARM** mới phân biệt được
*bị chặn* (403) với *vào được* (200). Sau khi vá, request không xác thực cũng bị chặn
trước khi Kudu kịp trả 401 → **401 ở SCM chính là dấu hiệu luật chưa ăn**.

`ai-failure-log.md` #24. Bài học mang sang D14: **mã trạng thái "không phải mã bị chặn"
không chứng minh là không bị chặn** — và cùng họ với "fail-closed" của M9: thứ nhìn như
đang bảo vệ mà thật ra không.

### 2. "IP công khai của máy" là **hai** địa chỉ, không phải một

Hotspot đi qua CGNAT: lấy mẫu 70 lần ra **đúng hai** IP (`14.162.xxx.xxx`,
`113.22.xxx.xxx`), ~50/50, không có cái thứ ba. Hai dải cách nhau quá xa để gộp CIDR.
Khai một cái thì **cứ hai request có một cái 403**, và triệu chứng "lúc được lúc không"
rất dễ đổ oan cho độ trễ của luật.

Trước đó WARP còn làm phép đo sai nặng hơn: IP là dải anycast `104.28.0.0/16` dùng chung
của Cloudflare, đổi theo từng request, và đường mặc định đi IPv6.

`known-issues.md` #11. **Trước khi whitelist bất cứ đâu: tắt VPN, rồi lấy mẫu nhiều lần.**

### 3. WARP là công cụ đo, không chỉ là thứ gây phiền

**Bật WARP là có ngay một IP ngoài whitelist trong vài giây** — không cần đổi mạng, mượn
máy hay dựng VM. Chính nó cho phép đo chứng minh ngược cho SCM. Thứ sáng làm hỏng phép đo
thì trưa thành dụng cụ.

## Ba sai sót của phiên này

1. **Dấu phẩy trong `description` của `ip_restriction`** → Azure trả `400 BadRequest`
   (`Description cannot contain ';' or ','`). `fmt`, `validate` và cả `plan` đều xanh vì đây
   là ràng buộc của **API đích**, không có trong schema provider — chỉ nổ lúc apply, sau khi
   đã mất 5 phút tạo phụ thuộc. `ai-failure-log.md` #23.
2. **Giả định `scm_use_main_ip_restriction` là đủ** — viết ở PR #30, tự bắt ở PR #31 (mục 1).
3. **Mở PR trong lúc `destroy` đang chạy** → job `terraform plan` đỏ oan; chạy lại sau
   `Destroy complete` thì xanh, code không đổi. `known-issues.md` #9 đã bổ sung: điều kiện
   của job chỉ phân biệt được *tắt hẳn* với *bật hẳn*, không nhận ra **dở dang** — dù đang
   đi lên hay đi xuống. **Đừng mở PR hay re-run job giữa lúc `make up`/`make down` chưa xong.**

## Hai lần `make up` hỏng trước khi thành công

| Lần | Kết quả | Nguyên nhân |
|---|---|---|
| 10:42 | pha 1 đỏ | MySQL trả `InternalServerError` (Tracking ID `c9b20ada-…`) — lỗi phía Azure, chạy lại là qua |
| 10:48 | pha 1 đỏ | dấu phẩy trong `description` (sai số 1 ở trên) |
| 10:54 | xong 11:25 | 38 resource ở pha 2 |

Script chạy `up` **dừng hẳn khi pha 1 đỏ** thay vì chạy tiếp pha 2 — giữ đúng bài học D12
là đừng để `EXIT=0` của chuỗi shell che mất thất bại giữa chừng. `destroy` cũng không bọc
`timeout`, và xác nhận bằng dòng `Destroy complete`, không tin mỗi exit code.

## Đã vào `main` phiên này

| PR | Nội dung |
|---|---|
| #30 | Luật truy cập IP cho 4 bề mặt, `m6-check.yml`, `.gitignore` tfvars, khung `evidence/M6.md`, 5 Decision |
| #31 | Vá lỗ hổng SCM, `evidence/M6.md` đầy đủ, trả nốt ô cuối của D12, `ai-failure-log.md` #23 + #24 |

`evidence/M4.md` **không còn ô `CHƯA ĐO` nào** — `configreferences` của slot staging đã đo
bù ở phiên này (`Resolved` / `UserAssigned`).

## Hệ quả đã biết, đừng truy nhầm

Job `terraform-plan` của CI chạy **không có** tfvars nên luôn thấy `allowed_ips = {}`. Khi
môi trường thật đang bật, plan của CI sẽ báo **xoá** các luật truy cập (`0 to add, 2 to
change`). Đó là cái giá của việc không commit IP cá nhân, **không phải drift**. Đừng "sửa"
bằng cách đẩy IP lên GitHub Variable.

Lưu ý phụ: artifact `plan.txt` vì thế **chứa IP thật**. Repo đang private nên không lộ —
nếu chuyển public thì phải xử lý trước.

## Bắt đầu D14 thế nào

D14 **không tốn tiền, không cần Azure**. Đọc `notes/d14-prep.md` (4 quyết định phải chốt,
6 bước, bảng bẫy, gợi ý trả lời 3 câu tự kiểm tra). Ba việc đầu:

```bash
cd ~/"Màn hình nền/devops_vsf/.claude/worktrees/d12"
git checkout -b feat/d14-ci-extended origin/main

# 1. Trivy đã cài chưa
trivy --version

# 2. Đo thật trước khi chốt chính sách Q4 — LƯU Ý app/be/ chứ không phải app/
docker build -t opsboard-be:d14 app/be/
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW opsboard-be:d14

# 3. Mở Settings → Rules → protect-main, ĐỌC danh sách required checks hiện tại
```

**Hai thứ chặn, phải xử lý trước khi viết job:**

- **Q4 chưa chốt** (`--ignore-unfixed` hay không). Bối cảnh: D5 đo ảnh **Rust** ra 0 CVE,
  nhưng app đã đổi sang **.NET** (`aspnet:10.0-noble-chiseled`) và Decision 2026-09-18 ghi
  rõ *"cần đo lại bằng Trivy"*. Thêm nữa Q10 chốt **hai** service nên có **hai** image phải
  quét, `app/fe` là Next.js/Node thường nhiều CVE hơn. Lấy số trước, chọn chính sách sau.
- **Required checks có thể đang trỏ tên job đã chết.** `notes/d6.md:19` ghi
  `rust (fmt, clippy, test)` — job đó không còn. Nhưng các PR gần đây merge bình thường,
  nên hoặc đã sửa, hoặc ruleset không cưỡng chế như tưởng. **Xác minh, đừng đoán** — nếu là
  vế thứ hai thì đó chính là một bằng chứng M9 thật: *bảo vệ tưởng có mà không có*.

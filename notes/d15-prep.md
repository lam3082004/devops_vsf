# D15 — Kế hoạch chi tiết: cross-review lần 1 + dọn tuần 3

Guide gốc: `docs/guides/d15-cross-review-1.md` · Deliverable: `review-<tên bạn kia>.md`
Nhật ký: `notes/d15.md` (tạo khi làm) · Phiên trước (D14): `notes/d14.md`

> **HOÃN — quyết định 2026-09-23.** Chưa có repo của intern kia, mà 2/4 ô "Xong khi" phụ
> thuộc người đó, nên nhảy sang D16 (`notes/d16-prep.md`) thay vì đứng chờ. **File này
> không mất hiệu lực** — có link repo là quay lại làm tiếp từ bước 0.
>
> Một thay đổi khi quay lại: bước 4 (**M8 lần 2** + 6 ảnh Portal) là việc duy nhất ở đây
> không cần ai mà lại cần môi trường bật. D16 cũng phải `make up`, nên **cân nhắc làm bước
> 4 ngay trong cửa sổ đó** rồi gạch khỏi D15.

## Đọc 60 giây này trước

| | |
|---|---|
| **Tốn tiền?** | **CÓ** — bước 4 (`make down` → `make up`) là bước duy nhất. ~45 phút. Phải hỏi trước khi chạy. |
| **Chặn đường** | **Cần repo của bạn intern kia.** 2/4 ô "Xong khi" phụ thuộc người khác. |
| **Làm được ngay không cần ai** | bước 1 (tự review), bước 3 (README), bước 5 (tự kiểm tra) |
| **Gộp thêm** | 6 ảnh Portal còn nợ — chụp trong cửa sổ bước 4, **đừng bật môi trường riêng** |

## Cái chặn thật: D15 cần một người thứ hai

Guide mở đầu bằng *"**Cần:** bạn intern kia đã có repo"*. Không có thì hai ô này không làm được:

- [ ] `review-<tên>.md` merged
- [ ] phát hiện "Chặn" trong repo mình đã có PR sửa hoặc lý do

**Việc đầu tiên của D15, làm trước mọi thứ khác:** nhắn bạn kia xin link repo + quyền đọc,
và hẹn thời điểm cả hai có commit ổn định trên `main`. Nếu phải chờ thì làm bước 1, 3, 4
trước — ba bước đó không cần ai.

Nếu **không có** bạn intern nào để ghép đôi, đó là câu hỏi cho mentor chứ không phải thứ
tự quyết được. Ghi vào mục "Chưa định nghĩa" của plan như Q1–Q5.

## Chuỗi việc

```
[0] xin link repo bạn kia ──▶ [2] review repo họ ──▶ [6] nhận review, sửa
      (chờ được)                                            │
[1] tự review repo mình ──▶ [3] README nháp ──▶ [4] M8 lần 2 + 6 ảnh ──▶ [5] tự kiểm tra
      (làm ngay)
```

### 0. Xin link repo (5 phút, làm đầu tiên vì có độ trễ)

- [ ] Nhắn bạn kia: link repo + quyền đọc + xác nhận `main` đang ổn định.
- [ ] Gửi lại link repo mình + commit SHA hiện tại.

### 1. Tự review repo mình trước (1 giờ, không cần ai)

Chạy đúng checklist mục 2 của guide lên **chính repo này**, trước khi đọc repo người khác.
Hai lý do: câu tự kiểm tra #1 của guide hỏi thẳng *"phát hiện nào của bạn kia bạn cũng đang
mắc?"*, và đọc repo mình bằng con mắt reviewer là cách nhanh nhất để biết checklist ấy
thật sự hỏi gì.

Đã biết trước, **không cần đi tìm lại** — đây là những chỗ repo này sẽ tự chấm mình:

| Nhóm | Trạng thái repo này | Nguồn |
|---|---|---|
| Secret | `.gitignore` chặn `terraform.tfvars`; gitleaks quét toàn lịch sử; hook pre-commit | `evidence/M9.md` |
| Secret | ⚠️ artifact `plan.txt` của CI **chứa IP thật** — repo private nên chưa lộ, chuyển public là phải xử lý | Decision 2026-09-23 |
| Quyền | 3 principal tách role riêng trên Key Vault; CI dùng OIDC, không secret | Decision 2026-09-18 |
| Mạng | ⚠️ `fe` chưa có Web App trong `infra/` → D13 mới phủ 4 bề mặt, không phải 8. **D16 dựng `fe` nên khi quay lại D15 phải kiểm lại dòng này** — nếu `evidence/M6.md` chưa có đủ 8 bề mặt thì đó là một phát hiện Chặn của chính mình | Decision 2026-09-23 |
| M1/M4 | ACR admin tắt, pull bằng user-assigned MI, KV reference có `keyVaultReferenceIdentity` | `evidence/M4.md` |
| Tái lập | ⚠️ `purge_protection_enabled = false` trên Key Vault — cố ý, để destroy→apply lại cùng tên | Decision 2026-09-18 |
| CI gate | 8 job, tất cả required, `bypass_actors` trống, không `continue-on-error` | `evidence/M9.md` |
| Terraform | Terraform ghim `1.15.8`; lock file đã commit | `ci.yml` |
| Chi phí | Plan **P0v3**, MySQL **8.4 B1ms** | Decision 2026-09-17 (D8) |
| Chi phí | Autoscale trần **2 instance** — là *luật* trong `CLAUDE.md`, chưa dựng (D19) | `CLAUDE.md` |

Ba dấu ⚠️ ở trên là thứ một reviewer giỏi **sẽ** tìm ra. Tốt nhất là mình nêu trước trong
`review-*.md` của chính mình hoặc trong phần trả lời, kèm lý do — chứ không để họ phát hiện.

### 2. Review repo bạn kia (1,5 giờ)

Không cần chạy hạ tầng của họ (không có quyền subscription). Đọc: code, plan artifact,
CI runs, evidence.

**Thứ tự đọc hiệu quả nhất** — bắt đầu từ chỗ lỗi hay nấp, không đọc từ trên xuống:

1. `git log -p` tìm secret trong **lịch sử**, không chỉ ở `HEAD`. File state/plan nhị phân có bị commit không.
2. Tab **Actions** → một PR bất kỳ: job nào required, có `continue-on-error` không, gitleaks có `fetch-depth: 0` không.
3. **Settings → Rules** nếu xem được: required checks có khớp tên job đang chạy không, `bypass_actors` có trống không. *(D14 của repo này tìm ra lỗ đúng ở đây — 4/6 job không được cưỡng chế.)*
4. Terraform: scope của `azurerm_role_assignment` (subscription hay resource), `purge_protection`, tên toàn cầu có hậu tố chưa.
5. MySQL: có bật "Allow public access from any Azure service" không.
6. `evidence/`: là log thô/ảnh thật hay chỉ lời mô tả.

Mẫu file ở mục 3 của guide. **Luật của guide: mỗi phát hiện phải có tình huống cụ thể**
("destroy → apply sẽ lỗi vì vault soft-deleted"), không viết chung chung "nên cải thiện
bảo mật". Bắt buộc có **≥ 2 điểm làm tốt**.

- [ ] `review-<tên>.md` → PR vào repo mình → merge → gửi link cho bạn kia.

### 3. README nháp (30 phút, không cần ai)

Guide mục 5 đòi: prerequisite · biến cần set · `make up` / `make down` · teardown.

README hiện tại (42 dòng) mới chỉ chú thích **repo có những gì**, chưa hướng dẫn dựng lại.
Nguyên liệu đã có sẵn, chỉ việc gom:

| Mục | Lấy từ |
|---|---|
| Prereq | `terraform 1.15.8`, `az cli`, `docker`, `make`, `.NET 10 SDK`, `node 24` — xem `ci.yml` |
| Biến cần set | `infra/app/terraform.tfvars.example` + `backend.hcl` |
| up/down | `Makefile` target `up`, `down`, `check-empty`, `outputs` |
| Teardown | `make down` + `make check-empty` |

Cảnh báo phải ghi vào README: `make up` là **2 pha** (pha 1 `-target` Web App, pha 2 phần
còn lại) và **dừng hẳn nếu pha 1 đỏ** — người lạ chạy mà không biết sẽ tưởng hỏng.

### 4. M8 lần 2 + 6 ảnh Portal — **BƯỚC DUY NHẤT TỐN TIỀN**

> **Hỏi trước khi chạy.** `make down` → `make up` ≈ 45 phút (M8 lần 1: apply 24 phút,
> destroy 19 phút). Đây cũng là cửa sổ duy nhất để trả nốt 6 ảnh còn nợ.

Guide mục 5: chạy lại sau các thay đổi tuần 3 (ACR + Key Vault + IP whitelist) → cập nhật
`evidence/M8.md` **lần 2**. Ý nghĩa: chứng minh hạ tầng vẫn dựng lại được từ số 0 **sau khi**
đã thêm ba thứ đó, không phải chỉ đúng ở bản D10.

Trình tự trong cửa sổ đó:

```
1. warp-cli disconnect          ← BẮT BUỘC. WARP làm hỏng cả đo IP (known-issues #11)
                                   lẫn mạng container (notes/d14.md), và whitelist sẽ 403
2. make check-empty             ← xác nhận điểm xuất phát sạch
3. đo IP công khai nhiều lần    ← CGNAT cho HAI IP, phải khai cả hai vào terraform.tfvars
4. make up                      ← ~25 phút, 2 pha
5. terraform output -raw name_suffix   ← ghi lại NGAY, mọi ảnh sẽ mang suffix này
6. chụp 6 ảnh                   ← notes/screenshot-debt.md
7. verify + cập nhật evidence/M8.md lần 2
8. make down  →  make check-empty
```

- [ ] `evidence/M8.md` thêm bảng lần 2 (thời gian apply/destroy, số resource, `plan` = No changes)
- [ ] 6 ảnh → `notes/screenshot-debt.md`

**Hai bẫy đã biết, đừng dính lại:**
- **Đừng mở PR hay re-run job trong lúc `make up`/`make down` chưa xong** — job `terraform plan`
  không phân biệt được trạng thái *dở dang*, sẽ đỏ oan. Đã dính 2 lần: `known-issues.md` #9.
- **Đừng mở nhiều PR cùng lúc** — `terraform plan` dùng chung concurrency group, các PR huỷ
  job của nhau và `cancelled` hiện thành `fail`. `known-issues.md` #13.

### 5. Ba câu tự kiểm tra (15 phút)

1. Phát hiện nào của bạn kia bạn cũng đang mắc?
2. Phát hiện nào khó thấy nhất nếu chỉ đọc code (cần xem plan artifact hoặc CI run)?
3. *(thêm, từ bài học D14)* Có lớp bảo vệ nào trong repo họ **nhìn như đang hoạt động mà
   thật ra không chặn gì** không? Hai ví dụ đã gặp trong repo này: `scm_use_main_ip_restriction`
   bật nhưng SCM vẫn Allow (D13), và required checks thiếu 2 job nên check đỏ vẫn merge được (D14).

### 6. Nhận review từ bạn kia

Guide mục 4, làm đúng thứ tự:
- [ ] Mỗi phát hiện "Chặn" → một issue hoặc một dòng trong plan.
- [ ] Sửa qua **PR riêng**, tham chiếu phát hiện số mấy.
- [ ] **Không đồng ý thì trả lời lý do trong issue, không lờ đi.**

## Xong khi (theo guide)

- [ ] `review-<tên>.md` merged — *cần bạn kia*
- [ ] Phát hiện "Chặn" trong repo mình đã có PR sửa hoặc lý do — *cần bạn kia*
- [ ] `evidence/M8.md` lần 2 — *cần `make up`, tốn tiền*
- [ ] README nháp — *làm được ngay*

## Ước lượng

| Việc | Thời gian | Cần gì |
|---|---|---|
| 0 — xin link | 5 phút | bạn kia |
| 1 — tự review | 1 giờ | — |
| 2 — review repo họ | 1,5 giờ | link repo |
| 3 — README nháp | 30 phút | — |
| 4 — M8 lần 2 + 6 ảnh | ~1,5 giờ (45 phút là chờ máy) | **tiền** + trình duyệt để chụp |
| 5 — tự kiểm tra | 15 phút | — |
| 6 — nhận review, sửa | tuỳ số phát hiện | bạn kia |

## Lưu ý cho phiên có AI

- Từ D7 AI được sinh code; mỗi PR phải có mục `## AI usage`.
- **Claude không chụp được ảnh Portal nếu Chrome extension chưa kết nối.** Kiểm tra trước
  bằng `list_connected_browsers` — phiên D14 nó trả về rỗng nên 6 ảnh vẫn treo. Muốn Claude
  chụp thì cài + đăng nhập extension tại `claude.ai/chrome` **cùng tài khoản** với Claude
  Code, rồi khởi động lại Chrome. Không thì tự chụp tay theo `notes/screenshot-debt.md`.
- Mọi lệnh tốn tiền (`terraform apply`, `make up`, `make down`) phải được xác nhận trong phiên.

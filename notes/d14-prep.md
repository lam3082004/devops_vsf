# D14 — Kế hoạch chi tiết: CI đầy đủ + bằng chứng đỏ (M9)

Guide gốc: `docs/guides/d14-ci-extended.md` · Bằng chứng: `evidence/M9.md` · Nhật ký: `notes/d14.md` (tạo khi làm).
Phiên trước (D13): `notes/d13.md`.

> **Đề bài nói thẳng:** "cốt lõi của M9 **không phải** pipeline chạy xanh mà là **pipeline
> chặn được cái sai**." Nên phần nặng nhất của D14 không phải viết job, mà là **6 PR cố
> tình sai** cộng một lần **thử bấm merge khi đang đỏ** và chụp lại việc GitHub từ chối.

## Tin tốt: D14 **không tốn tiền** và **không cần môi trường Azure**

Toàn bộ D14 chạy trên GitHub Actions + máy local. `make up` không cần thiết.
Ngoại lệ duy nhất: job `terraform-plan` có sẵn sẽ chỉ plan được **pha 1** khi môi trường
tắt — điều đó **bình thường**, không phải lỗi của D14 (job tự in `::notice`).

→ Không có bước nào phải hỏi tiền. Cứ làm.

## Tình trạng đầu vào (đo 2026-09-23, trên `main` sau PR #31)

`.github/workflows/ci.yml` hiện có **6 job**:

| Job hiện có | Tên hiển thị | Guide yêu cầu |
|---|---|---|
| `gitleaks` | `gitleaks` | ✅ có |
| `dotnet` | `dotnet (format, build, test)` | ✅ gộp `lint` + `test` của guide |
| `frontend` | `frontend (lint, build)` | ✅ (guide viết từ thời một service) |
| `terraform` | `terraform (fmt, validate)` | ✅ có |
| `terraform-plan` | `terraform plan (infra/app)` | ✅ có |
| `azure-oidc` | `azure login (OIDC)` | (ngoài danh sách guide, giữ) |

**Thiếu đúng hai job:** `docker-build` và `trivy`.

Ngoài ra `.github/workflows/m6-check.yml` là workflow riêng, chạy tay, **không** phải
required check — đừng thêm nó vào ruleset, nó cần môi trường Azure bật.

## Bốn thứ phải chốt trước khi viết job

### A. Q4 — chính sách Trivy (đang CHẶN D14)

`docs/plans/active/...` mục Câu hỏi còn treo: *"Q4. Trivy 'không còn CVE' có cho
`--ignore-unfixed` không?"* **Chưa có câu trả lời.** Phải chốt trước khi viết job, vì nó
quyết định job đỏ hay xanh.

Bối cảnh đã có trong repo, đừng đo lại từ đầu:

- D5 quét ảnh **Rust** (musl + scratch): **0 CVE ở mọi mức**, không cần `--ignore-unfixed`.
- Nhưng app **đã đổi sang .NET** (Decision 2026-09-18). Base image giờ là
  `aspnet:10.0-noble-chiseled`, framework-dependent. Decision đó ghi rõ:
  *"không đạt lại 0 CVE tuyệt đối như bản Rust … **cần đo lại bằng Trivy**."*
- Và từ Q10 có **hai** image phải quét: `app/be` và `app/fe` (Next.js/Node — thường
  nhiều CVE hơn .NET chiselled).

**Việc đầu tiên của D14, làm trước khi bàn chính sách:** quét thật cả hai image ở local,
lấy số. Có số rồi mới chọn chính sách được, chứ chọn trước là chọn mò.

```bash
docker build -t opsboard-be:d14 app/be/          # LƯU Ý: app/be/ chứ không phải app/
docker build -t opsboard-fe:d14 app/fe/
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW opsboard-be:d14
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW opsboard-fe:d14
# rồi so với:
trivy image --ignore-unfixed --severity CRITICAL,HIGH opsboard-be:d14
```

Khung để chốt Q4 (ghi vào Decisions, kèm số thật):

| Lựa chọn | Khi nào hợp lý |
|---|---|
| `CRITICAL,HIGH` + `--ignore-unfixed`, fail khi >0 | nếu đo ra còn CVE chưa có bản vá — đây là mặc định thực dụng của ngành; phải kèm lịch xem lại |
| `CRITICAL,HIGH` **không** `--ignore-unfixed` | nếu đo ra đã sạch — chặt hơn, và đúng tinh thần "0 CVE" của đề |
| thêm `MEDIUM,LOW` | chỉ khi số thật sự bằng 0, nếu không CI sẽ đỏ triền miên vì thứ không sửa được |

Bẫy: **`trivy` chưa cài trên máy** (plan mục Công cụ: *"chưa có gitleaks, trivy"* — gitleaks
thì D6 đã cài rồi, trivy thì chưa kiểm lại). Kiểm `trivy --version` trước.

### B. Required checks đang liệt kê tên job **cũ**

`notes/d6.md:19` ghi required checks là: `gitleaks`, **`rust (fmt, clippy, test)`**,
`terraform (fmt, validate)`. Job `rust ...` **không còn tồn tại** (đã đổi sang `dotnet ...`
khi chuyển ngôn ngữ). Guide cảnh báo đúng chỗ này: *"Tên job ổn định — đổi tên = phải sửa
required checks."*

→ **Việc bắt buộc:** mở Settings → Rules → `protect-main` → đọc danh sách required checks
hiện tại **trước khi làm gì khác**, chụp lại làm ảnh "trước". Nếu `rust (...)` vẫn còn thì
đó là một required check không bao giờ chạy — về lý thuyết mọi PR sẽ kẹt "Expected —
waiting for status". Thực tế các PR gần đây (#27, #29, #30, #31) **merge được bình thường**,
nên hoặc nó đã được sửa, hoặc ruleset không cưỡng chế như tưởng. **Phải xác minh, đừng
đoán** — đây có thể là một phát hiện M9 thật sự (bảo vệ tưởng có mà không có).

### C. `docker-build` và `trivy`: một job hay hai

Guide nói rõ bẫy: hai job khác nhau mà **không truyền image** thì Trivy quét nhầm image
hoặc kéo từ Internet.

**Đề xuất: một job cho mỗi service** (`docker-build-be`, `docker-build-fe`), trong đó build
rồi scan ngay, image nằm trong docker daemon của cùng runner. Đơn giản hơn hẳn việc
`docker save` → upload artifact → download → `docker load`, và không có chỗ để lệch.

Đổi lại: tên job dài hơn và phải thêm **hai** required check. Chấp nhận được.

### D. Bao nhiêu required check là đủ

Guide bảo thêm **tất cả** job ở mục 1. Với repo này là 8:
`gitleaks`, `dotnet (format, build, test)`, `frontend (lint, build)`,
`terraform (fmt, validate)`, `terraform plan (infra/app)`, `azure login (OIDC)`,
`docker-build-be (+trivy)`, `docker-build-fe (+trivy)`.

Cân nhắc riêng `terraform plan (infra/app)`: nó gọi Azure thật và **đã đỏ oan hai lần**
(`known-issues.md` #9 — một lần vì môi trường apply dở, một lần vì chạy trúng lúc destroy).
Làm nó required nghĩa là mọi PR đều kẹt khi môi trường đang dở dang. Hai đường:

- **Giữ required** (đúng guide) + kỷ luật "không mở PR khi `make up`/`make down` chưa xong".
- **Không required** + ghi Decision nói rõ vì sao. Đề bài yêu cầu "tất cả job" nên
  đường này phải giải trình được.

→ Đề xuất: **giữ required**, vì D14 là bài về fail-closed. Ghi rủi ro vào `known-issues.md`.

## Chuỗi việc

```
[0] đo Trivy, chốt Q4 ─▶ [1] PR thêm docker-build + trivy ─▶ [2] sửa ruleset
                                                                   │
[5] evidence/M9.md ◀── [4] 1 PR xanh đối chứng ◀── [3] 6 PR đỏ + thử merge
```

### 0. Đo và chốt (không tốn tiền)

- [ ] `trivy --version`, chưa có thì cài (ghim version, giống cách D6 cài gitleaks bằng binary).
- [ ] Build + scan cả `app/be` và `app/fe`, lưu output thô vào `evidence/raw/d14-trivy-*.txt`.
- [ ] Chốt **Q4** kèm số thật → ghi vào mục Decisions của plan, xoá Q4 khỏi danh sách câu hỏi treo.
- [ ] Đọc + chụp danh sách required checks **hiện tại** của `protect-main`.

### 1. PR thêm job (không tốn tiền)

- [ ] `docker-build-be`: `docker build app/be/` với tag `${{ github.sha }}`, **không push**.
- [ ] Bước Trivy ngay sau, cùng job, quét **image** (không phải thư mục source — bẫy của guide).
- [ ] Cache database Trivy (guide mục 2.4) để không đỏ vì mạng.
- [ ] **Không** `continue-on-error` ở bước scan (guide mục 2.5 — đây chính là "fail-closed").
- [ ] Lặp cho `docker-build-fe`.
- [ ] Ghim action bên thứ ba theo commit SHA, token quyền tối thiểu, concurrency theo PR.
- [ ] PR + mục `## AI usage` → CI xanh → squash merge.

### 2. Ruleset (làm trên web, chụp màn hình)

- [ ] Settings → Rules → `protect-main` → Required status checks: thêm đủ 8 tên.
- [ ] Xoá tên job đã chết (`rust (fmt, clippy, test)`) nếu còn.
- [ ] Kiểm **bypass list trống** — guide cảnh báo "admin bypass còn bật → merge được khi đỏ".
- [ ] Chụp ảnh danh sách sau khi sửa.

### 3. Sáu PR đỏ — phần chính của M9

Mỗi PR: nhánh riêng, đổi đúng **một** thứ, chụp tab Checks, rồi **đóng PR + xoá nhánh**.

| # | Làm gì | Job phải đỏ | Ghi chú |
|---|---|---|---|
| 1 | Cắm secret giả | `gitleaks` | **Dùng mẫu từ test fixtures của gitleaks**, đừng tự bịa — bịa thì không khớp mẫu, CI xanh và tưởng CI hỏng |
| 2 | Làm hỏng Dockerfile | `docker-build-be` | ví dụ đổi tên lệnh trong `RUN` |
| 3 | Cho một test fail | `dotnet (...)` | sửa 1 assert trong `app/be.Tests` |
| 4 | Sai format Terraform | `terraform (fmt, validate)` | thụt lề lệch một dòng là đủ |
| 5 | Base image cũ có CVE | `trivy` | *(tuỳ chọn)* ví dụ `aspnet:8.0` không chiselled |
| 6 | **Thử bấm merge khi đang đỏ** | — | **BẮT BUỘC CHỤP.** Đây là ô đắt nhất của M9 |

- [ ] Sau khi xong: `git log --all --oneline | head` và tìm lại chuỗi secret giả — **xác minh nó không nằm trên `main`**. Guide dặn riêng việc này.

### 4. Một PR xanh đối chứng

- [ ] PR nhỏ vô hại (sửa một dòng README), toàn bộ 8 check xanh → merge được → chụp.
- [ ] Không có ô này thì 6 ô đỏ chưa chứng minh gì: có thể pipeline đỏ với **mọi** PR.

### 5. `evidence/M9.md`

- [ ] Bảng 6 dòng đỏ + 1 dòng xanh, mỗi dòng có **link run** và ảnh.
- [ ] Danh sách required checks (ảnh trước/sau nếu có sửa).
- [ ] Chính sách Trivy đã chốt + số CVE thật của cả hai image.
- [ ] Trả lời 3 câu tự kiểm tra (gợi ý ở cuối file này).

## Bẫy

| Bẫy | Dấu hiệu | Xử lý |
|---|---|---|
| Trivy quét thư mục source thay vì image | 0 CVE đẹp bất thường, không thấy CVE của OS package | `trivy image <tag>`, không phải `trivy fs .` |
| `docker-build` và `trivy` tách job, không truyền image | Trivy quét image khác hoặc kéo từ Internet | gộp một job cho mỗi service |
| Secret giả quá "giả" | `gitleaks` xanh ở PR #1 | lấy mẫu từ test fixtures của gitleaks |
| Admin bypass còn bật | merge được khi đỏ → ô #6 hỏng | kiểm bypass list trống |
| Required check lọc theo đường dẫn | PR không đụng đường dẫn đó kẹt "waiting" mãi | đừng lọc `paths` cho job required |
| Tên job đổi mà quên sửa ruleset | required check không bao giờ chạy | xem mục B — repo này **đang** có nguy cơ đó |
| `terraform plan` đỏ oan | môi trường đang dở dang | `known-issues.md` #9; đừng mở PR giữa lúc `make up`/`make down` |
| Đổi base image để hết CVE làm app không chạy | Trivy xanh nhưng container chết | chạy thử image local trước khi đẩy lên PR |

## Gợi ý trả lời 3 câu tự kiểm tra

1. **Fail-closed nghĩa là gì với bước scan?** Bước quét mà **lỗi vì bất kỳ lý do gì** — mạng
   hỏng, không tải được database CVE, timeout — phải làm job **đỏ**, không được coi là "không
   tìm thấy CVE nên xanh". `continue-on-error: true` biến một cổng bảo mật thành đồ trang trí:
   nó vẫn hiện trong tab Checks, vẫn xanh, nhưng không còn chặn gì. Cùng họ với bài học D13
   (`scm_use_main_ip_restriction`): **thứ nhìn như đang bảo vệ mà thật ra không**.
2. **Vì sao build image trong CI mà không push?** PR đến từ nhánh bất kỳ, kể cả của người
   ngoài; push nghĩa là cho code chưa review ghi vào registry mà production kéo từ đó. Build
   thì chứng minh được "Dockerfile còn build được + image quét sạch" mà không cho PR quyền
   ghi vào ACR. Push là việc của CD (D16), sau khi đã merge vào `main`.
3. **Hôm nay xanh, tuần sau Trivy đỏ mà code không đổi — xử lý thế nào?** Bình thường:
   database CVE cập nhật liên tục, một CVE mới công bố cho base image cũ là đủ. Không tắt
   scan, không nới chính sách để lấy màu xanh. Trình tự: đọc CVE → có bản vá thì rebuild với
   base image mới (thường chỉ cần đổi tag) → chưa có bản vá thì thêm vào file bỏ qua **kèm mã
   CVE, lý do, và ngày xem lại**, rồi ghi `known-issues.md`. Điểm mấu chốt: mục bỏ qua phải
   **hết hạn**, nếu không nó thành vĩnh viễn và không ai nhớ vì sao.

## Ước lượng

| Việc | Thời gian |
|---|---|
| 0 — đo Trivy, chốt Q4 | 45 phút (lần build đầu của `fe` có thể lâu) |
| 1 — PR thêm 2 job | 1 giờ |
| 2 — ruleset | 20 phút |
| 3 — 6 PR đỏ | 1,5 giờ (phần lớn là chờ CI và chụp ảnh) |
| 4 — PR xanh | 15 phút |
| 5 — `evidence/M9.md` | 45 phút |

Không có bước nào tốn tiền Azure.

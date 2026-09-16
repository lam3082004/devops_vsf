# D6 — GitHub repo · ruleset · gitleaks · CI v1

**Cần:** câu trả lời **Q2** (repo public/private) · **Chi phí:** 0 · **Nhật ký:** `notes/d6.md`

## Mục tiêu
Từ bài này, **luật trunk-based được máy cưỡng chế**, không dựa vào kỷ luật: không ai (kể cả bạn) push thẳng `main`, PR đỏ không merge được, secret bị chặn từ máy local.

## 1. Chuẩn bị repo local
1. Kiểm tra `.gitignore` có: file state Terraform, thư mục `.terraform/`, file plan, `.env`, file `*.tfvars` chứa giá trị cá nhân, thư mục build, file ảnh screenshot quá nặng (nếu muốn).
2. Rà soát trước khi push lần đầu (đặc biệt nếu repo **public**):
   - `notes/` có subscription ID, tenant ID — không phải secret nhưng cân nhắc.
   - Không có email cá nhân, mật khẩu, connection string.
3. Commit đầu tiên trên `main` local.

## 2. Tạo repo GitHub
1. GitHub → **New repository** → tên ví dụ `devops-vsf` → Public/Private theo Q2 → **không** tạo README/gitignore từ GitHub (tránh xung đột).
2. Thêm remote và push `main` lần đầu (lần duy nhất push thẳng — trước khi có ruleset).

## 3. Cài đặt merge
**Settings → General → Pull Requests**:
- ✅ Allow squash merging · ❌ Allow merge commits · ❌ Allow rebase merging
- ✅ Automatically delete head branches

## 4. Ruleset cho `main`
**Settings → Rules → Rulesets → New ruleset → New branch ruleset**:

| Mục | Chọn |
|---|---|
| Ruleset name | `protect-main` |
| Enforcement status | **Active** |
| Bypass list | **để trống** — kể cả admin (đề: "kể cả khi làm một mình") |
| Target branches | **Include default branch** |
| Restrict deletions | ✅ |
| Require linear history | ✅ (khớp squash merge) |
| Require a pull request before merging | ✅ · Required approvals: **0** nếu làm một mình (ghi rõ lý do trong note) |
| Require status checks to pass | ✅ — **thêm check sau bước 7**, vì tên check chỉ hiện sau khi workflow chạy ít nhất một lần |
| Block force pushes | ✅ |

**Kiểm chứng:** thử push một commit thẳng lên `main` từ máy → phải bị từ chối. Chụp output.

## 5. gitleaks pre-commit hook
1. Cài gitleaks (bản phát hành chính thức — máy hiện **chưa có**, kiểm tra 2026-09-15) hoặc framework pre-commit có hook gitleaks.
2. Cấu hình hook chạy trên phần **staged** trước mỗi commit.
3. **Kiểm chứng:** tạo file thử chứa một chuỗi có dạng khoá truy cập giả (tra "gitleaks test fixtures" để lấy mẫu dạng giả, **không dùng khoá thật**) → commit → **bị chặn**. Chụp output. Xoá file thử.
4. Ghi vào README sau này: người mới clone repo phải cài hook.

## 6. PR template
Tạo file template PR trong thư mục `.github` với các mục:
- **Tóm tắt** thay đổi
- **AI usage** — phần nào AI sinh, bạn đã sửa gì, có lỗi AI nào ghi vào `ai-failure-log.md`
- **Bằng chứng** — lệnh đã chạy, output, link run CI
- **Checklist** — không secret · đã chạy local · đã cập nhật docs/evidence nếu cần

## 7. CI v1 (tự viết workflow)

| Thuộc tính | Yêu cầu |
|---|---|
| Tên file | `ci.yml` (CD sẽ là file riêng) |
| Trigger | pull request vào `main` (có thể thêm chạy tay) |
| Quyền token | chỉ đọc nội dung repo |
| Job `gitleaks` | checkout **toàn bộ lịch sử** (không chỉ commit cuối) → quét → đỏ khi phát hiện |
| Job `terraform` | cài Terraform đúng phiên bản ghim → `fmt` ở chế độ kiểm tra → `init` **không backend** → `validate` |
| Action bên thứ ba | ghim phiên bản cụ thể (tốt hơn nữa: ghim theo commit SHA) |

`infra/` lúc này có thể chỉ gồm khai báo provider — đủ để `validate` chạy.

**Kiểm chứng:**
1. Nhánh `chore/ci-v1` → PR → hai job chạy xanh. Chụp.
2. Quay lại ruleset → **Require status checks** → thêm đúng tên hai job → Save.
3. Nhánh `test/red-secret` → thêm chuỗi khoá giả (bỏ qua hook local bằng cách tạm tắt hook, **chỉ để thử CI**) → PR → gitleaks **đỏ** → nút merge **bị khoá**. Chụp cả hai → đây là bằng chứng M9 sớm, lưu vào `evidence/M9.md`.
4. Đóng PR, **xoá nhánh** thử, bật lại hook.

## 8. File khung
Tạo qua PR: `ai-failure-log.md` (bảng: ngày · công cụ AI · yêu cầu · AI sinh ra gì · sai ở đâu · phát hiện bằng cách nào · sửa thế nào), `known-issues.md` (3 mục: chưa xong · biết là sai · làm lại sẽ khác), `evidence/README.md` (mục lục M1–M11).

## Bẫy
- Repo private trên GitHub Free: ruleset tạo được nhưng **không được cưỡng chế** → test push thẳng `main` sẽ lộ ra.
- Required check đặt sai tên (tên job khác tên hiển thị) → PR kẹt "Expected — waiting for status".
- gitleaks trong CI chỉ quét commit cuối → secret nằm ở commit giữa PR lọt qua.
- Workflow chạy trên `pull_request` từ fork không có quyền secret — với repo cá nhân thường không gặp, nhưng nên biết.
- Để admin trong bypass list = bạn vẫn merge được khi đỏ → bằng chứng M9 vô giá trị.

## Tự kiểm tra
1. Vì sao cần gitleaks ở cả hook và CI?
2. Status check chạy nhưng không "required" thì chuyện gì xảy ra?
3. Secret thật đã lên GitHub thì phải làm gì?

## Xong khi
- [ ] push thẳng `main` bị từ chối · [ ] hook chặn secret giả · [ ] PR xanh với 2 check required · [ ] PR secret giả đỏ + merge bị khoá (screenshot) · [ ] file khung đã merge

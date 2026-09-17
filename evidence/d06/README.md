# D6 — GitHub repo · ruleset · gitleaks · CI v1 (2026-09-17)

Repo: `lam3082004/devops_vsf` (**private**, tài khoản GitHub Pro) · Nhật ký: `notes/d6.md`

## Ba lớp chặn đã dựng và đã kiểm chứng

| # | Lớp | Kiểm chứng | Bằng chứng |
|---|---|---|---|
| 1 | **Ruleset `protect-main`** cấm push thẳng | `git push origin main` → **rejected** | `push-to-main-rejected.log` |
| 2 | **Pre-commit hook gitleaks** (local) | commit file chứa khoá AWS giả → **bị chặn** | `pre-commit-hook-blocked.log` |
| 3 | **CI gitleaks** (không bỏ qua được) | PR #2 cắm secret giả → job **đỏ** | `ci-gitleaks-red.log` |
| | **Required status checks** | PR đỏ → **không merge được** | `pr2-merge-blocked.json`, `pr2-merge-attempt-rejected.log` |

### Trích bằng chứng

Push thẳng `main`:
```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
 ! [remote rejected] main -> main (push declined due to repository rule violations)
```

CI bắt secret trong PR #2:
```
Finding:  aws_access_key_id = REDACTED
RuleID:   aws-access-token
File:     fake-creds.txt
leaks found: 1
```

Thử merge PR đang đỏ:
```
X Pull request lam3082004/devops_vsf#2 is not mergeable: the base branch policy prohibits the merge.
```

## Cấu hình repo

| Mục | Giá trị |
|---|---|
| Visibility | private (Pro → ruleset vẫn được cưỡng chế) |
| Merge | **squash-only**; tắt merge commit và rebase; tự xoá nhánh sau merge |
| Ruleset `protect-main` | Active, **bypass list trống** (kể cả admin) |
| Rules | deletion · non_fast_forward · required_linear_history · pull_request (0 approval) · **required_status_checks** |
| Required checks | `gitleaks` · `rust (fmt, clippy, test)` · `terraform (fmt, validate)` |

## CI v1 — `.github/workflows/ci.yml`

Trigger `pull_request` vào `main`, `permissions: contents: read`, concurrency huỷ run cũ.

| Job | Nội dung |
|---|---|
| `gitleaks` | checkout `fetch-depth: 0` → binary gitleaks **ghim 8.30.1** → `gitleaks detect --exit-code 1` |
| `rust` | `cargo fmt --check` · `clippy -- -D warnings` · `cargo test` (có cache cargo) |
| `terraform` | bỏ qua nếu chưa có `infra/`; từ D7 sẽ chạy `fmt -check` + `validate` |

## Lỗi gặp và cách sửa

**`gitleaks/gitleaks-action@v2` làm CI đỏ oan.** Action cần `pull-requests: write` để bình luận vào PR, trong khi workflow chỉ cấp `contents: read` → `RequestError [HttpError]: Resource not accessible by integration`.
→ Sửa: bỏ action, cài binary ghim version rồi chạy trực tiếp. Giữ token ở mức chỉ đọc và chủ động được version. Ghi case này vào `ai-failure-log.md` (#3).

## Dọn dẹp
PR #2 đã đóng, nhánh `test/red-secret` đã xoá. GitHub chỉ còn nhánh `main`. Kiểm chứng: `git log main -S "AKIA..."` → **0 kết quả**; `gitleaks detect` toàn repo → **no leaks found**.

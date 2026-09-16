# D16 — CD pipeline

**Cần:** D13, D14 · **Chi phí:** có · **Bằng chứng:** `evidence/M10.md`

## Mục tiêu (M10)
Merge vào `main` → build → push ACR → deploy slot staging → swap. **Chỉ `main` được deploy.**

## 1. Danh tính deploy
`id-gh-deploy` (từ D7), bổ sung role — least privilege:

| Role | Scope | Để |
|---|---|---|
| AcrPush | ACR | push image |
| Website Contributor | Web App (bao gồm slot) | đổi image slot, swap, sửa access restriction tạm (D17) |

Không cần quyền state Terraform, không cần Key Vault. Federated credential chỉ khớp `main` (hoặc environment `production`).

## 2. GitHub environment `production`
Settings → Environments → New → `production` → **Deployment branches: chỉ `main`**. (Tuỳ chọn: required reviewers = chính bạn để có nút duyệt trước swap.)

## 3. `cd.yml` — yêu cầu cần đạt (file riêng, không gộp với CI)

| Thuộc tính | Yêu cầu |
|---|---|
| Trigger | push vào `main` (+ chạy tay để thử, vẫn bị giới hạn bởi environment) |
| Đồng thời | một nhóm deploy duy nhất, **không huỷ** lần chạy đang dở (swap dở dang nguy hiểm hơn chờ) |
| Quyền token | đọc nội dung + ghi id-token |
| Environment | `production` |

Các bước:

| # | Bước | Kiểm tra |
|---|---|---|
| 1 | Checkout đúng commit | SHA = commit vừa merge |
| 2 | Đăng nhập Azure (OIDC, `id-gh-deploy`) | |
| 3 | Đăng nhập ACR bằng danh tính Entra | không dùng admin |
| 4 | Build image với SHA · tag `<acr>/vsf-app:<sha>` | không tag `latest` |
| 5 | (Tuỳ chọn) Trivy scan lại image sẽ push | cùng chính sách CI |
| 6 | Push image | ACR có tag mới |
| 7 | Đặt image slot **staging** = tag SHA | |
| 8 | Chờ staging sẵn sàng + đúng SHA | **D17** — bài này tạm chờ cố định hoặc bỏ qua |
| 9 | Swap staging → production | |
| 10 | Ghi job summary: SHA, tag, thời gian từng bước, URL | |

## 4. Kiểm chứng "chỉ main"
1. Chạy tay workflow từ nhánh `feat/…` → bị environment chặn **hoặc** đăng nhập Azure thất bại (subject không khớp). Chụp.
2. PR bình thường → CI chạy, **CD không chạy**.

## 5. Chạy end-to-end (M10)
1. Nhánh `feat/…` đổi một chi tiết thấy được (ví dụ trường `msg` trong `/version` hay tên app) → PR → CI xanh → squash merge.
2. Mở run CD → chờ xong.
3. `/version` production = SHA commit merge.
4. `evidence/M10.md`: link PR · link run CI · link run CD · bảng thời gian từng bước · output `/version` trước/sau · screenshot ACR tag.

## Bẫy
- Terraform `make up` sau đó kéo image về placeholder → `ignore_changes` chưa đúng thuộc tính (D9).
- CD chạy trên merge nhưng Terraform môi trường đang `down` → deploy thất bại. Quy trình: `make up` trước khi merge PR có deploy.
- Build trong CD khác bản đã test trong CI (khác base image vì tag trôi) → ghim base image.
- Hai merge liên tiếp → hai CD chồng nhau nếu thiếu nhóm đồng thời.
- Quyền Website Contributor gán ở scope app nhưng không bao gồm slot → kiểm tra thao tác trên slot.

## Tự kiểm tra
1. Ba lớp nào bảo đảm "chỉ main được deploy"?
2. Vì sao không huỷ CD đang chạy khi có merge mới?
3. Rollback nhanh nhất sau khi CD xong nhưng bản mới lỗi?

## Xong khi
- [ ] merge → production đổi SHA không thao tác tay · [ ] nhánh khác không deploy được (screenshot) · [ ] `evidence/M10.md`

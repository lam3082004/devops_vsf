# Prompt cho Codex CLI — đóng nốt các mục chưa đạt trước demo D25

Chạy từ gốc repo, nhánh `chore/d25-close-gaps`:

```bash
codex exec --sandbox workspace-write -C "$PWD" - < docs/prompts/codex-close-gaps.md
```

---

## Vai trò và bối cảnh

Bạn làm việc trong repo `devops_vsf` (Azure App Service internship). Đọc theo thứ tự trước khi sửa bất cứ gì:
`CLAUDE.md` (luật project, thắng prompt này khi xung đột) → `topic.md` (authority: M1–M11, S1–S3, deliverables) →
`docs/plans/active/azure-app-service-internship.md` (mục "Tiến độ") → `known-issues.md` → `evidence/README.md`.

Ngày hôm nay là 2026-10-05. Môi trường Azure `jcip0s` **đang bật**, Free Trial hết hạn 15/10, demo phải xong trước 15/10.

Người dùng đã chốt 05/10 (ghi nguyên văn ý, đừng diễn giải lại):

| Mục | Quyết định |
|---|---|
| S2 (MI → MySQL bằng Entra) | **Đóng kèm blocker**: tài khoản không có directory role, tenant `allowedToCreateApps=false` nên không cấp được Graph permission cho identity MySQL. Ghi blocker, **không** sinh Terraform |
| S3 (Private Endpoint + jump VM) | **Bỏ**, ghi blocker/lý do |
| M8 lần 2 (destroy → apply toàn bộ hạ tầng hiện tại) | **Không làm trước demo**; ghi rõ "sẽ làm sau demo, sau khi gỡ PoC (#23)" |
| Ảnh M9 "merge bị khoá" | Việc của người điều phối (cần trình duyệt), **không phải việc của bạn** — đừng sửa `evidence/M9.md` mục ảnh |

## Luật cứng (vi phạm = hỏng bài)

1. **Trung thực trên hết.** "Đóng kèm blocker" ≠ "ĐẠT". Mọi nơi bạn ghi trạng thái S2, S3, M8-lần-2 phải dùng chữ
   **"Không đạt — đóng có chủ đích (blocker: …)"** hoặc **"Hoãn tới sau demo"**. Cấm các chữ "ĐẠT", "xong", "hoàn thành" cho 3 mục này.
2. Chỉ ghi số liệu/lệnh có trong repo hoặc do bạn tự chạy trong phiên này. Không bịa giá, không bịa kết quả, không ước lượng chi phí S3 nếu repo
   chưa có số — viết "chưa tra giá" thay vì đoán.
3. **Cấm:** `terraform apply|destroy`, `az ... create|delete|update`, `git commit|push`, đụng `.github/workflows/`, `infra/`, `app/`,
   `evidence/raw/*` đã có (chỉ **đọc** chúng). Không `make up|down`.
4. Không secret, email cá nhân, IP thật (`104.30.x.x` đã che — giữ nguyên dạng che) vào file nào.
5. Smallest diff. Chỉ sửa/tạo đúng các file liệt kê bên dưới. Giữ giọng văn, tiêu đề, độ dày comment của file xung quanh (tiếng Việt).
6. Tài liệu là deliverable chấm điểm: link tương đối phải trỏ tới file có thật (kiểm bằng `ls`).

## Việc cần làm

### T1 — `evidence/S2.md` (tạo mới)
Nội dung: yêu cầu S2 trích từ `topic.md`; trạng thái **"Không đạt — đóng có chủ đích"**; bằng chứng blocker lấy từ
`evidence/raw/s2-graph-probe-20261005.txt` (trích đúng các dòng: directory role rỗng, `allowedToCreateApps=false`, MySQL chưa có
`authConfig`/identity); giải thích **cơ chế** vì sao cần Graph permission (identity của MySQL Flexible Server phải đọc được thư mục
Entra để ánh xạ người dùng/identity; cấp quyền Graph application cho identity cần Privileged Role Administrator hoặc Global
Administrator của tenant — tài khoản này không có); hiện trạng thay thế đã có và rủi ro còn lại (`known-issues.md` #33 mục 3:
app dùng tài khoản admin MySQL, mật khẩu ở Key Vault); **"nếu có đủ quyền thì làm gì"** 5–7 bước ngắn (không viết HCL).

### T2 — `evidence/S3.md` (tạo mới)
Yêu cầu S3 từ `topic.md`; trạng thái **"Không đạt — bỏ có chủ đích"**; lý do có căn cứ trong repo: MySQL ở Southeast Asia, app ở Central India
(`known-issues.md` "Biết là sai" #6), M3/M6 đang dựa trên firewall theo outbound IP + access restriction với bằng chứng 8 bề mặt, plan chung
với PoC (#23), hạn Free Trial 15/10, thêm tài nguyên (VNet, Private Endpoint, private DNS zone, jump VM) mà không có chỗ chạy thử an toàn
trước demo. Thiết kế dự kiến nếu làm (sơ đồ mermaid **tách luồng traffic và luồng auth** nếu vẽ). Không số tiền nếu repo chưa có.

### T3 — Bảng Stretch trong `evidence/README.md`
Thêm mục **"Stretch"** sau bảng "Must-have", 3 dòng:
- S1: trạng thái dựa trên bằng chứng có thật — đọc `.github/workflows/ci.yml` (job `docker build + trivy`), `.trivyignore`,
  `evidence/raw/d14-trivy-*`, `evidence/M9.md`. Ghi đúng cổng đang là `CRITICAL,HIGH` và **nêu ngoại lệ CVE-2026-84782 hết hạn 15/10**
  (`known-issues.md` #31). Nếu bạn kết luận S1 đạt, phải trỏ tới run/log chứng minh cổng đỏ thật khi có CVE (tìm trong `evidence/`, `notes/d14.md`,
  `known-issues.md` #31 — CD run `36807348815`); không tìm thấy thì ghi "đạt về cấu hình, chưa có ảnh đỏ riêng" và nói rõ.
- S2 → link `S2.md`; S3 → link `S3.md` (đúng chữ trạng thái ở luật 1).
Tạo thêm `evidence/S1.md` **chỉ khi** cần gom bằng chứng rải rác (≤ 40 dòng, toàn link).

### T4 — M8 lần 2: ghi hoãn
- `evidence/M8.md`: thêm mục cuối "Hoãn tới sau demo (05/10)": trạng thái **"Hoãn tới sau demo"**, vì sao (PoC `app-obs-demo-jcip0s` trên plan, #23;
  hạn demo; chi phí/rủi ro), và checklist 6–8 bước **lấy từ tài liệu có sẵn** (`README.md` teardown, `Makefile` `down`/`up`/`check-empty`,
  `known-issues.md` #23, #7, `notes/d10.md`): gỡ PoC → kiểm `az resource list -g rg-vsf-dev --tag purpose=poc` rỗng → `make down` →
  `make check-empty` → `make up` (3 pha) → verify → `plan` No changes → ghi log vào `evidence/raw/`. Ghi rõ đây là hạng mục tốn tiền cần người dùng xác nhận.
- `known-issues.md`: sửa dòng #7 của bảng "Chưa xong" — thêm "(05/10: người dùng chốt làm sau demo)" mà **không** xoá nội dung cũ.

### T5 — Bảng đối chiếu `topic.md` trong plan
Trong `docs/plans/active/azure-app-service-internship.md`, ngay dưới tiêu đề mục "Tiến độ", chèn đoạn **"Đối chiếu topic.md — 05/10"** gồm 3 bảng ngắn:
Must-have M1–M11 (trạng thái lấy từ `evidence/README.md`, M2 = "0 non-200 theo chữ topic.md; chờ mentor về timeout #21"), Stretch S1–S3 (theo T3),
Deliverables 1–10 (kiểm từng file bằng `ls`; #8 `review-<tên>.md` ×2 = **chưa có — không có người ghép đôi, người dùng chốt bỏ 30/09 (#6)**;
#10 demo = chưa diễn ra). Không đổi các đoạn "Tiến độ" cũ. Cập nhật dòng "Bài tiếp" nếu cần cho khớp.

### T6 — Tự kiểm số liệu tài liệu (chỉ sửa khi sai thật)
Đếm bằng lệnh và so với lời khẳng định trong `README.md`, `ai-failure-log.md`, `known-issues.md`, `evidence/README.md`:
số case `ai-failure-log.md` (tuyên bố 45), bảng 8 case tiêu biểu, số mục `known-issues.md` (tuyên bố 35 + 7), số required check trong ruleset
(`evidence/raw/d14-ruleset-after-*.json` so với số job `ci.yml`). Sai thì sửa con số, ghi lại trong báo cáo cuối. Đúng thì thôi.

## Kiểm tra trước khi báo xong

```bash
git status --short                      # chỉ các file ở trên, không file nào khác
git diff --stat
grep -rn "S2\|S3" evidence/README.md | grep -iE "đạt|xong|hoàn thành" # mỗi dòng phải là "Không đạt"/"không phải ĐẠT", không được là khẳng định đạt
# link tương đối trong file bạn sửa/tạo: kiểm bằng ls từng đường dẫn
```

## Báo cáo cuối (đúng 4 mục)
1. Outcome · 2. File đã tạo/sửa (đường dẫn) · 3. Lệnh kiểm đã chạy + kết quả thật · 4. Rủi ro/điều chưa chắc (nếu có). Không tuyên bố "xong" nếu một lệnh kiểm chưa chạy.

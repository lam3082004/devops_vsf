# D23 — Kế hoạch chi tiết: agent giới hạn quyền (agent đọc sự cố)

Guide gốc: `docs/guides/d23-limited-agent-review-2.md` · Nhật ký: `notes/d23.md` (tạo khi làm) · Bằng chứng: `evidence/agent.md`
· Phiên trước: `notes/d22.md` · Bài sau: `notes/d24-prep.md`

> Viết 2026-09-30 (người dùng: "lên plan chi tiết cho day 23 và day24"). Môi trường `jcip0s` **đang bật**, `main` = `7f36c65`.

## Đọc 60 giây này trước

| | |
|---|---|
| **Việc chính** | (1) Sửa `known-issues.md` #17: dựng lại state `infra/bootstrap` bằng `import`, vì agent cần danh tính ở bootstrap · (2) Danh tính `id-agent-triage` + quyền chỉ đọc bằng Terraform · (3) Workflow `agent-triage.yml` (OIDC, không secret) chạy KQL tóm tắt sự cố · (4) ≥ 7 phép **chứng minh ngược** có lỗi nguyên văn · (5) Rủi ro còn lại |
| **Không làm** | **Cross-review lần 2**, người dùng chốt bỏ 30/09 vì không có repo của intern kia (D15 cũng vậy). Deliverable #8 của `topic.md` (`review-<tên>.md` × 2) ghi là **chưa làm** trong `known-issues.md` |
| **Tốn tiền?** | Gần 0: MI, role assignment, custom role và query Log Analytics đều miễn phí; phút GitHub Actions nằm trong hạn mức free. Merge PR = **1 lần CD swap production** |
| **Ai chạy** | AI: code, `plan`, import, workflow, bằng chứng. 👤 Người dùng duyệt từng bước ở mục "Cần duyệt" |
| **Xong khi** (guide) | bảng thiết kế quyền · ≥ 3 chứng minh ngược có lỗi nguyên văn · rủi ro còn lại · ~~review lần 2 merged~~ (bỏ) |

## Quyết định (người dùng chốt 30/09)

| # | Quyết định | Vì sao |
|---|---|---|
| A | Agent = **"agent đọc sự cố"**: đọc log, metric và alert, tóm tắt nguyên nhân 5xx. **Không** ghi gì | `topic.md` chưa đặc tả. Loại này hợp nhất với M11 vừa làm và có rủi ro nhỏ nhất. "Agent vận hành hẹp" (restart/swap) bị loại vì quyền đó đụng thẳng production |
| B | Agent chạy trên **GitHub Actions + OIDC** | Tenant cấm app registration (Q6), nên agent chạy ngoài Azure chỉ có một đường không secret: user-assigned MI + federated credential. Giống mẫu CD |
| C | MI + federated credential ở **bootstrap**, role assignment ở **`infra/app`** | Client id cố định qua các vòng `make down`/`up` → biến GitHub set một lần; quyền sinh/mất cùng môi trường. Mẫu có sẵn: `data "azurerm_user_assigned_identity"` ở `infra/app/deploy-permissions.tf:7` |
| D | Quyền Azure: **Log Analytics Reader** trên workspace + custom role **`vsf-agent-alert-reader`** trên `rg-vsf-dev` | Không dùng Monitoring Reader vì role đó có `*/read`, đọc được cả access restriction (chứa IP cá nhân). Mẫu custom role: `infra/app/ci-permissions.tf:12` |
| E | Bỏ cross-review 2 | Không có người ghép đôi |

## Bảng thiết kế quyền (bắt buộc trong bài nộp)

| Lớp | Danh tính | Quyền | Scope | Vì sao đủ | Vì sao không rộng hơn |
|---|---|---|---|---|---|
| Azure | `id-agent-triage` (UAMI, `rg-vsf-bootstrap`) | Log Analytics Reader | `log-vsf-<suffix>` | chạy KQL trên mọi bảng M11 | role đã loại `workspaces/sharedKeys/read`; không scope RG/subscription |
| Azure | như trên | `vsf-agent-alert-reader`: `Microsoft.AlertsManagement/alerts/read`, `Microsoft.Insights/metrics/read`, `Microsoft.Insights/metricDefinitions/read` | `rg-vsf-dev` | đọc alert đang Fired + metric Plan/Web App/MySQL | không `*/read` (IP whitelist, cấu hình), không `config/list/action` (app settings), không data plane Key Vault |
| GitHub | token OIDC của workflow | `contents: read`, `id-token: write` | repo này, environment `agent-triage` chỉ nhận `main` | checkout + xin token | không PAT, không `issues/pull-requests: write` |
| Local | Claude Code (coding agent) | ruleset `protect-main` (0 bypass) + Bash guard harness | repo | mở PR được | push `main` bị ruleset chặn |

## Chuỗi việc

### 0. Chuẩn bị (không tốn tiền)
- [ ] 👤 Thêm `alert_email = "<email>"` vào `infra/app/terraform.tfvars` của **checkout chính** (việc tồn từ 29/09). Nếu thiếu, apply từ đó sẽ xoá email receiver.
- [ ] `terraform plan` app từ `main` = No changes (điểm xuất phát sạch).

### 1. Sửa #17: import state bootstrap (không đổi gì trên Azure)
- Chạy từ **checkout chính** `infra/bootstrap/`, **không** từ worktree: state là file local, gitignored (quyết định D7), và worktree sẽ bị xoá. Chính kiểu dọn thư mục đó đã làm mất state lần trước.
- File tạm `imports.tf` (không commit), **18** `import` block (= số `resource` trong `infra/bootstrap/*.tf`, đếm 30/09). ID lấy bằng `az` (chỉ đọc):

| Resource Terraform | Số |
|---|---|
| `random_string.suffix` · `azurerm_resource_group.bootstrap` · `azurerm_storage_account.tfstate` · `azurerm_storage_container.tfstate` | 4 |
| `azurerm_user_assigned_identity.gh_plan` / `gh_deploy` | 2 |
| `azurerm_federated_identity_credential.*` (`infra/bootstrap/cicd.tf`) | 8 |
| `azurerm_role_assignment.me_blob_contributor` / `gh_plan_reader` / `gh_plan_state_blob` / `gh_deploy_state_blob` | 4 |- ⚠️ **Bẫy:** `random_string.suffix` quyết định tên storage account. Nếu import lệch thuộc tính (`special`, `upper`…), plan sẽ đòi **thay** nó, kéo theo **xoá storage state**. Luật: `plan` phải ra **`N to import, 0 to add, 0 to change, 0 to destroy`**. Lệch dù chỉ 1 thì **dừng**, không apply, sửa code cho khớp thực tế (hoặc `ignore_changes`).
- [ ] **Cần duyệt:** apply chỉ import → `plan` = **No changes** → xoá `imports.tf` → cập nhật #17.

### 2. Code (nhánh `feat/d23-agent-triage`)
- `infra/bootstrap/agent.tf`: `azurerm_user_assigned_identity.agent_triage` + 2 federated credential `environment:agent-triage` (thường + immutable, chép mẫu `cicd.tf:120-137`) + output `agent_triage_client_id`.
- `infra/app/agent-permissions.tf`: `data` MI, `azurerm_role_assignment` Log Analytics Reader trên `azurerm_log_analytics_workspace.main`, `azurerm_role_definition` + assignment `vsf-agent-alert-reader` trên RG.
- `.github/workflows/agent-triage.yml`: `workflow_dispatch`, input `mode` (`triage` | `prove`), `environment: agent-triage`, `permissions: {contents: read, id-token: write}`, `azure/login` bằng `vars.AZURE_AGENT_CLIENT_ID`.
- `scripts/agent-triage.sh`: KQL lấy từ `docs/logging.md` / Workbook (5xx theo app 1 giờ, endpoint lỗi nhiều nhất, exception gần nhất kèm `trace_id`), `az graph query` cho alert Fired → markdown vào `$GITHUB_STEP_SUMMARY`.
- `scripts/agent-prove.sh`: mỗi phép bị cấm phải **thất bại đúng mã lỗi** (bảng mục 5). Script in stderr nguyên văn và `exit 1` nếu có phép nào **thành công** hoặc lỗi sai loại (ví dụ lỗi mạng thay vì lỗi RBAC).
- Kiểm local: `shellcheck`, `terraform fmt -check`, `terraform validate` (2 root), `plan` app/bootstrap đúng số resource mong đợi. PR có mục `## AI usage`.

### 3. Apply + cấu hình GitHub (cần duyệt)
- [ ] Apply bootstrap: **1 MI + 2 federated credential**.
- [ ] Apply app: **1 role definition + 2 role assignment**.
- [ ] Tạo environment `agent-triage` (deployment branch policy: chỉ `main`) + biến repo `AZURE_AGENT_CLIENT_ID` bằng `gh api` / `gh variable set`. Ghi lệnh vào README mục Bootstrap (D24).
- [ ] `plan` cả 2 root = No changes.

### 4. Merge + chạy
- [ ] **Cần duyệt:** merge PR (= CD swap).
- [ ] Dispatch `mode=triage`, rồi `mode=prove` từ `main`; lưu log run vào `evidence/raw/`.

### 5. Chứng minh ngược → `evidence/agent.md`

| Thử (danh tính agent) | Mong đợi |
|---|---|
| KQL 5xx 24h | **thành công**, có bảng |
| `az role assignment list --assignee <agent> --all` | đúng 2 dòng, khớp bảng thiết kế |
| `az keyvault secret show --vault-name kv-vsf-<suffix> -n <secret DB>` | **Forbidden** (KV ở chế độ RBAC, không có tường lửa mạng, nên đây là lỗi quyền chứ không phải lỗi mạng) |
| `az webapp config appsettings list` (`be`) | **AuthorizationFailed** (`Microsoft.Web/sites/config/list/action`) |
| `az webapp restart` (`be`) | **AuthorizationFailed** |
| `az group create -n rg-agent-should-fail` | **AuthorizationFailed** |
| `az role assignment create --role Owner` cho chính nó, scope `rg-vsf-dev` | **AuthorizationFailed** |
| dispatch `agent-triage.yml` với `--ref` nhánh khác `main` | environment chặn: "…not allowed to deploy to agent-triage…" |
| (coding agent) `git push` commit thử lên `main` | **GH013 repository rule violations** (cần duyệt riêng) |

### 6. Rủi ro còn lại (ghi trong `evidence/agent.md`)
- Log chứa dữ liệu cá nhân: `AppServiceHTTPLogs.CIp` (IP người dùng), tên người trong ticket, nội dung exception.
- Log Analytics Reader đọc **mọi bảng** của workspace, kể cả dữ liệu của PoC nếu PoC ghi chung.
- Kết quả nằm trong job summary: ai đọc được repo đều xem được.
- Nếu ai đó sửa workflow và merge vào `main`, workflow chạy dưới quyền agent. Quyền vẫn bị giới hạn bởi role, nhưng việc merge bị chặn bởi PR review + CI.
- Cách giảm: role Data Reader theo từng bảng hoặc truy vấn resource-context; giữ repo private; không log nội dung request body.

### 7. Đóng
- [ ] `notes/d23.md`, `ai-failure-log.md` (nếu AI sinh sai), plan mục D23 ✅, `known-issues.md` (#17 đã sửa · cross-review chưa làm).

## Cần duyệt (hỏi đúng lúc, không hỏi gộp trước)
1. Apply import bootstrap · 2. Apply bootstrap (MI agent) · 3. Apply app (quyền agent) · 4. Tạo environment + biến GitHub ·
5. Merge PR (CD swap) · 6. Push thử lên `main`.

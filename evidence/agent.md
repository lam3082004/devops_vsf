# Agent giới hạn quyền: "agent đọc sự cố" `id-agent-triage` (D23)

Đề bài `topic.md` chỉ ghi "bài agent giới hạn quyền". Người dùng chốt ngày 30/09 (`notes/d23-prep.md` quyết định A–E):
agent **đọc** log, metric, alert và tóm tắt sự cố 5xx, **không ghi** gì. Chạy trên GitHub Actions bằng OIDC, không
có secret. Nhật ký làm: `notes/d23.md`.

| | |
|---|---|
| Danh tính | `id-agent-triage`, user-assigned MI ở `rg-vsf-bootstrap` (`infra/bootstrap/agent.tf`), client id `7df24d2f-ae65-4a73-bf54-ea8576799156`, object id `61139c60-cd46-42e3-b6c5-e8d9151c42fc` |
| Quyền | `infra/app/agent-permissions.tf` |
| Chạy | `.github/workflows/agent-triage.yml` (`mode=triage` · `mode=prove`) → `scripts/agent-triage.sh`, `scripts/agent-prove.sh` |
| Agent là gì | Luật cố định (không LLM): chạy đúng các truy vấn mà `runbook.md` bảo người trực chạy tay, gom thành một báo cáo |

## 1. Bảng thiết kế quyền

| Lớp | Danh tính | Quyền | Scope | Vì sao đủ | Vì sao không rộng hơn |
|---|---|---|---|---|---|
| Azure | `id-agent-triage` | Log Analytics Reader | workspace `log-vsf-<s>` | chạy KQL trên mọi bảng M11 (HTTP/Console/Platform logs, `AppRequests`, `AppExceptions`) | role đã loại `workspaces/sharedKeys/*` nên không lấy được key để ghi log giả (phép 4). Scope là workspace, nên `*/read` của role không lan sang Web App hay Key Vault |
| Azure | như trên | custom `vsf-agent-alert-reader`: `Microsoft.AlertsManagement/alerts/read`, `Microsoft.Insights/metrics/read`, `Microsoft.Insights/metricDefinitions/read` | `rg-vsf-dev` | đọc alert Fired/Resolved và metric `Http5xx`/`Requests` | **không** dùng Monitoring Reader vì role đó có `*/read`, đọc được `ip_restriction` (IP cá nhân, phép 5) và mọi cấu hình. Không `config/list/action` (app settings, phép 6). Không data plane Key Vault (phép 3) |
| GitHub | token OIDC của job | `contents: read`, `id-token: write` | repo này, environment `agent-triage` chỉ nhận `main` | checkout + xin token | không PAT, không `issues`/`pull-requests: write`: agent chỉ ghi vào job summary |
| Entra | federated credential | subject `repo:…:environment:agent-triage` (dạng tên + immutable) | `id-agent-triage` | job có `environment: agent-triage` | không có subject `ref:`/`pull_request`: PR và job không khai environment đều không đổi được token |
| Local | Claude Code (coding agent viết ra agent này) | ruleset `protect-main` (0 bypass) + Bash guard của harness | repo | mở PR được | push `main` bị chặn (phép 11) |

Quyền thật, đo bằng tài khoản người vận hành (agent **không** tự liệt kê được quyền của mình, vì nó không có
`Microsoft.Authorization/roleAssignments/read`, và đó là điều đúng):

```
$ az role assignment list --assignee <principalId id-agent-triage> --all -o table    # 2026-10-01
Role                    Scope
----------------------  ---------------------------------------------------------------------------------------------
Log Analytics Reader    /subscriptions/<sub>/resourceGroups/rg-vsf-dev/providers/Microsoft.OperationalInsights/workspaces/log-vsf-jcip0s
vsf-agent-alert-reader  /subscriptions/<sub>/resourceGroups/rg-vsf-dev
```

Đúng 2 dòng, khớp bảng thiết kế.

## 2. Việc được phép: agent làm được việc của nó

Run [`36819513178`](https://github.com/lam3082004/devops_vsf/actions/runs/36819513178) (`mode=triage`, 24 giờ, từ `main`
`a3bccf4`, 05:23Z) — báo cáo đầy đủ: [`raw/d23-agent-triage-24h-36819513178.md`](raw/d23-agent-triage-24h-36819513178.md).
Danh tính trong báo cáo là client id của agent (`7df24d2f-…`), không phải người dùng.

- KQL: `be` 1 510 request / 0 5xx, `fe` 305 / 0 · container restart của 2 slot staging lúc CD #70 (04:57–04:59Z).
- Metric `Http5xx`: 0/1 530 (`be`), 0/310 (`fe`) — khớp số từ log.
- Kết luận của agent: "không có sự cố".

Run [`36819612636`](https://github.com/lam3082004/devops_vsf/actions/runs/36819612636) (72 giờ) —
[`raw/d23-agent-triage-72h-36819612636.md`](raw/d23-agent-triage-72h-36819612636.md): agent **thấy đúng** 2 lần alert
`5xx rate > 5%` Fired → Resolved của D22 (06:47:39 → 07:13:44Z và 14:07:38 → 14:33:37Z ngày 29/09) và Smart Detection
(#30). Tức là role `alerts/read` scope RG đủ cho Resource Graph `alertsmanagementresources`.

## 3. Chứng minh ngược

Phép 1–9: run [`36819621406`](https://github.com/lam3082004/devops_vsf/actions/runs/36819621406) (`mode=prove`, `main`,
05:26Z), **9/9 đạt**. Lỗi nguyên văn đầy đủ: [`raw/d23-agent-prove-36819621406.md`](raw/d23-agent-prove-36819621406.md)
(subscription id và tenant id đã che). Script đỏ nếu một phép bị cấm **thành công** hoặc thất bại **sai loại**, ví dụ
lỗi mạng thay vì lỗi RBAC.

| # | Thử (bằng danh tính agent) | Mong đợi | Kết quả | Lỗi nguyên văn (rút gọn) |
|---|---|---|---|---|
| 1 | KQL trên workspace | thành công | ✅ rc 0 | — |
| 2 | Resource Graph: alert của `rg-vsf-dev` | thành công | ✅ rc 0 | — |
| 3 | `az keyvault secret show --vault-name kv-vsf-jcip0s -n mysql-admin-password` | Forbidden | ✅ rc 1 | `(Forbidden) Caller is not authorized to perform action on resource. … Action: 'Microsoft.KeyVault/vaults/secrets/getSecret/action' … Assignment: (not found)` |
| 4 | `POST …/workspaces/log-vsf-jcip0s/sharedKeys` | AuthorizationFailed | ✅ rc 1 | `"code":"AuthorizationFailed" … does not have authorization to perform action 'Microsoft.OperationalInsights/workspaces/sharedKeys/action'` |
| 5 | `GET …/sites/app-vsf-jcip0s/config/web` (chứa `ip_restriction`) | AuthorizationFailed | ✅ rc 1 | `… perform action 'Microsoft.Web/sites/config/read' over scope '…/sites/app-vsf-jcip0s/config/web'` |
| 6 | `POST …/sites/app-vsf-jcip0s/config/appsettings/list` | AuthorizationFailed | ✅ rc 1 | `… perform action 'Microsoft.Web/sites/config/list/action'` |
| 7 | `POST …/sites/app-vsf-jcip0s/slots/staging/restart` | AuthorizationFailed | ✅ rc 1 | `… perform action 'Microsoft.Web/sites/slots/restart/action'` |
| 8 | `az group create -n rg-agent-should-fail` | AuthorizationFailed | ✅ rc 1 | `(AuthorizationFailed) … perform action 'Microsoft.Resources/subscriptions/resourcegroups/write'` |
| 9 | `az role assignment create --role Owner` cho chính nó, scope `rg-vsf-dev` | AuthorizationFailed | ✅ rc 1 | `(AuthorizationFailed) … perform action 'Microsoft.Authorization/roleAssignments/write'` |
| 10 | Dispatch `agent-triage.yml --ref docs/d24-finalize` | environment chặn | ✅ run [`36819791803`](https://github.com/lam3082004/devops_vsf/actions/runs/36819791803) failure, **0 step chạy** | `Branch "docs/d24-finalize" is not allowed to deploy to agent-triage due to environment protection rules.` |
| 11 | (coding agent) `git push origin <commit rỗng>:main` | ruleset chặn | ✅ `main` vẫn `a3bccf4` | `remote: error: GH013: Repository rule violations found for refs/heads/main. … - Changes must be made through a pull request. - 8 of 8 required status checks are expected. … ! [remote rejected] HEAD -> main (push declined due to repository rule violations)` |

Thiết kế an toàn của chính phép thử:
- **Restart thử trên slot staging**, không production: nếu quyền lỡ rộng thì hậu quả là restart staging.
- **Mọi stdout bị nuốt**: nếu quyền lỡ rộng thì giá trị secret hoặc shared key cũng không lọt vào log; chỉ stderr được in.
- `agent-prove.sh` **từ chối chạy bằng user**: chạy bằng `az login` của Owner thì mọi phép bị cấm sẽ thành công thật.
  Thử ngày 01/10: `!! danh tính hiện tại là user (…) — chỉ chạy bằng id-agent-triage`, exit 2.

## 4. Rủi ro còn lại

| Rủi ro trong quyền đã cấp | Vì sao còn | Cách giảm |
|---|---|---|
| **Log chứa dữ liệu cá nhân.** `AppServiceHTTPLogs.CIp`/`AppServiceIPSecAuditLogs.CIp` là IP người dùng; `AppExceptions` có thể chứa nội dung request, ví dụ tên tự nhập ở `X-User-Name`. Log request hiện không ghi tên này, nhưng không có gì ngăn một dòng log sau này ghi nó | Log Analytics Reader đọc **mọi bảng** của workspace; không có quyền theo cột | Script chỉ chọn cột cần (event, path, trace_id), không in `CIp` hay nguyên dòng log. Chặt hơn: role theo bảng (table-level RBAC) hoặc truy vấn resource-context chỉ trên Web App; app không log body request |
| **Workspace dùng chung với PoC.** Nếu PoC `app-obs-demo-jcip0s` ghi log vào `log-vsf-<s>` thì agent đọc được luôn | Quyền scope cả workspace | Tách workspace cho PoC, hoặc gỡ PoC (known-issues #23) |
| **Báo cáo nằm trong job summary và artifact**, ai đọc được repo đều xem được | Repo private, nhưng mọi collaborator đều thấy | Giữ repo private; báo cáo không chứa IP hay nội dung log |
| **Ai merge được vào `main` thì đổi được hành vi agent** (sửa script để chạy lệnh khác) | Workflow chạy code từ `main` | Quyền Azure vẫn chỉ đọc nên tệ nhất là đọc thêm bảng log; việc merge bị chặn bởi PR + 8 check (phép 11) |
| **Agent có thể chạy KQL nặng** (quét 30 ngày, mọi bảng) | Không có hạn mức truy vấn theo danh tính | `--hours` bị chặn 1–72; workspace có cap 0,2 GB/ngày cho **ingest**, query không tốn tiền ở gói PerGB2018. `concurrency` cho phép 1 run/lúc |

## 5. Tự kiểm tra (guide D23)

1. **Vì sao mỗi agent cần danh tính riêng thay vì dùng chung `id-gh-deploy`?** `id-gh-deploy` có Website Contributor
   trên RG (đổi image, swap, sửa access restriction). Dùng chung thì một lỗi trong script "chỉ đọc" cũng chạy dưới
   quyền ghi production. Danh tính riêng còn cho nhật ký đăng nhập riêng (biết request nào do agent gọi) và thu hồi
   riêng (xoá 2 role assignment, CD không bị ảnh hưởng).
2. **Quyền đọc log thành rủi ro dữ liệu thế nào?** Xem mục 4: log là nơi dữ liệu cá nhân rò vào mà không ai thiết kế
   (IP, tên, nội dung exception). "Chỉ đọc" không có nghĩa là "vô hại": đọc chính là đường rò.

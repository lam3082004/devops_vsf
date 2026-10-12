# Prompt cho sub-agent Sonnet — review AKS lần 1 (sau P0–P2)

Bạn là reviewer độc lập, **chỉ đọc**. Không sửa file, không `git commit/push`, không `terraform apply|destroy`, không
`az ... create|delete|update`, không `kubectl apply|delete|scale|set|rollout undo|exec`, không mở PR. Được chạy lệnh đọc:
`ls`, `grep`, `git`, `terraform -chdir=infra/aks validate|output|state list`, `kubectl get|describe|logs`, `kubectl kustomize`,
`az ... show|list`, `shellcheck`, `trivy config`, `make aks-verify`.
Repo `/home/tts/desktop/devops_vsf`, nhánh `feat/aks-infra` (thay đổi chưa commit: `git status`, `git diff`, file mới chưa track).

## Bối cảnh
Bài thực tập chính (`topic.md`, M1–M11) chạy trên App Service và **đã xong**; demo ≤ 14/10. Từ 12/10 người dùng yêu cầu làm
**thêm** AKS như phần *advanced*, với ràng buộc: **chỉ thêm, không đụng những thứ đã có/đã làm**. Subscription là Free Trial
(4 vCPU/region, hết hạn 15/10). Cluster `aks-vsf-dev` ở `rg-vsf-aks` (East Asia) đang chạy thật.

## Đọc trước
`CLAUDE.md` → `docs/plans/active/aks-advanced.md` (quyết định A–M, ranh giới "không đụng") → `docs/aks.md` →
`infra/aks/*.tf` → `infra/bootstrap/aks.tf` → `k8s/base/*.yaml` → `scripts/aks-render.sh`, `scripts/aks-verify.sh`,
`scripts/aks-cd.sh` → phần nối cuối `Makefile` → `.github/workflows/{ci-aks,cd-aks,aks-m6-check}.yml`.
Để so mẫu: `infra/app/{keyvault,identity,acr,db,alerts,monitoring}.tf`, `.github/workflows/cd.yml`, `scripts/demo-preflight.sh`.

## Việc 1 — Ranh giới "không đụng" có bị vi phạm không
1. `git diff main --stat` và `git status`: file **cũ** nào bị sửa? Với mỗi file cũ có diff, kiểm đó là **nối thêm cuối**, không
   sửa/xoá dòng cũ (`git diff main -- <file>` không được có dòng `-`). `infra/app/**`, `cd.yml`, `ci.yml`, `drift.yml`,
   `app/**`, `.trivyignore`, script cũ phải không có diff.
2. Resource của `infra/app` có bị **sửa** không: đọc `infra/aks/*.tf` tìm mọi resource có `resource_group_name = local.base_rg`
   hoặc scope trỏ vào ACR/Key Vault/MySQL cũ — mỗi cái phải là resource con MỚI (role assignment, firewall rule, database,
   secret), không phải resource mà `infra/app` đang quản. Có resource nào trùng tên/địa chỉ với thứ trong `infra/app` không?
3. `infra/bootstrap/aks.tf`: có đổi thuộc tính nào của identity/credential cũ không? Custom role ở scope subscription có rộng
   hơn mức mô tả không?
4. Rủi ro gián tiếp tới môi trường demo: dùng chung MySQL B1ms (kết nối, CPU), dùng chung Key Vault, action group. Có đường
   nào để sự cố/test trên AKS làm hỏng App Service hoặc bắn alert của bài chính không?

## Việc 2 — Đúng sai kỹ thuật
1. **Terraform**: `terraform -chdir=infra/aks validate`; đọc từng resource: thuộc tính sai/thiếu, phụ thuộc ngầm thiếu
   `depends_on`, thứ gì sẽ làm `plan` lần hai **không** ra No changes (drift do AKS tự điền), thứ gì làm `terraform destroy`
   gãy. `local.name_suffix` suy từ tên ACR — có trường hợp nào ra sai không?
2. **Bảo mật**: API server (`authorized_ip_ranges`, local account, Azure RBAC), role assignment có đúng least privilege không
   (đặc biệt 2 custom role ở `deploy-permissions.tf` và quyền `pods/exec`), `secretObjects` chép secret vào Secret của
   Kubernetes — ai đọc được? `fe` có đường nào chạm secret MySQL không? NetworkPolicy có thật sự chặn (đọc luật, và nếu
   cluster bật: `kubectl -n opsboard get networkpolicy -o yaml`)? Service `fe` chạy **HTTP** — đã ghi nhận ở đâu chưa?
3. **Manifest**: probe (readiness `/health`, liveness `/version`), `preStop sleep` + `terminationGracePeriodSeconds` so với
   `app/be/Program.cs`, `readOnlyRootFilesystem` với .NET và Next.js standalone, `HOSTNAME`, requests/limits so với node
   2 vCPU, HPA `maxReplicas`, Pod Security `restricted`. Chỗ nào sẽ gãy lúc rollout hoặc làm rớt request?
4. **Script**: `aks-render.sh` (xử lý lỗi, tag image, trường hợp allowed_ips rỗng, có in giá trị nhạy cảm không),
   `aks-verify.sh` (phép kiểm nào luôn xanh dù sai?), `aks-cd.sh` (rollback có chạy đúng thứ tự, có nuốt lỗi không).
5. **Workflow**: `cd-aks.yml` — `workflow_run` có thể bị kích bởi nhánh/PR không tin cậy không; chèn lệnh qua `inputs.sha`;
   bước nào nuốt lỗi; quyền token. `ci-aks.yml` — plan.txt có lộ IP không.

## Việc 3 — Luật project và sự thật
1. Luật `CLAUDE.md`: autoscale > 2 ở đâu không (`node_max_count`, HPA)? Secret/IP cá nhân trong file sẽ commit
   (`gitleaks detect --no-git --source .`; `grep -rnE '[0-9]{1,3}(\.[0-9]{1,3}){3}' infra/aks k8s scripts/aks-* docs/aks.md evidence/advanced evidence/raw/aks-*`
   — chỉ chấp nhận dải tài liệu, dải nội bộ và IP đã che)? `infra/aks/terraform.tfvars` có bị gitignore không?
2. Mọi khẳng định trong `docs/aks.md`, `docs/plans/active/aks-advanced.md`, `evidence/advanced/*.md`: số liệu, tên file, tên
   resource có khớp code và khớp cluster thật không? Liệt kê khẳng định **không kiểm chứng được**.
3. Comment trong code có khẳng định nào sai về Azure/Kubernetes không (ghi rõ nguồn nếu bạn chắc)?

## Báo cáo (tiếng Việt, ≤ 70 dòng)
Mỗi phát hiện: **mức** (P0 làm hỏng môi trường cũ / lộ bí mật · P1 sai kỹ thuật sẽ gãy hoặc sai sự thật · P2 nên sửa · P3 nhỏ)
· `file:dòng` · bằng chứng (lệnh + output ngắn) · cách sửa đề xuất. Không khen chung chung, không lặp lại mô tả code.
Kết thúc bằng: danh sách khẳng định **đã kiểm chứng đúng**, danh sách **không kiểm được và vì sao**, và phán quyết GO/NO-GO
cho việc mở PR `feat/aks-infra`.

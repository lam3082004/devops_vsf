# D10 — GATE: chuẩn bị (2026-09-20)

Dựa trên `docs/guides/d10-gate.md`. Đây là bài **bạn tự làm và tự trả lời
mentor** — tôi chuẩn bị checklist + câu trả lời mẫu theo đúng repo thật, bạn
đọc hiểu rồi tự nói lại, không đọc thuộc lòng.

## 1. Tiền kiểm (trước khi bắt đầu GATE)

- [ ] Mọi PR đã merge vào `main`: kiểm `git log --oneline -5` trên `main`,
      không còn nhánh `feat/*` nào của D9 còn treo. Hiện còn `feat/swagger-dev-only`
      (PR #12, chưa merge) — **không liên quan Terraform**, không chặn GATE,
      nhưng nên quyết định merge/bỏ trước khi bắt đầu cho gọn.
- [ ] Làm từ bản clone/checkout `main` sạch: `git status` phải trống (không
      có gì uncommitted) trước khi bắt đầu GATE.
- [ ] Không có resource tạo tay nào trong `rg-vsf-dev` (D9 không dùng Portal
      tay lần nào — chỉ 1 lần thử tạo/xoá App Service Plan tay để chẩn đoán
      429, đã xoá sạch ngay).

## 2. Lệnh chạy + log thô

**Quan trọng:** dùng `tee` để vừa xem output vừa ghi log, KHÔNG copy tay.

**Thứ tự thực tế (điều chỉnh 2026-09-20):** state đang **rỗng sẵn** (đã
`make down` cuối D9) nên chạy `destroy` trước là vô nghĩa — không có gì để
xoá, log không chứng minh được gì. Thứ tự đúng bây giờ: **apply từ rỗng →
verify → destroy**. Vẫn chứng minh đủ cả hai chiều. (Nếu sau này môi trường
đang bật khi làm GATE thì làm đúng thứ tự guide gốc: destroy → apply.)

**`make up` / `make down` HỎI `yes` TƯƠNG TÁC** (Makefile không có
`-auto-approve`, cố ý, để bạn còn cơ hội đọc plan):
- `make up` hỏi **2 lần** (pha 1 rồi pha 2) → gõ `yes` + Enter mỗi lần.
- `make down` hỏi **1 lần**.
- Khi chạy qua `| tee`, nếu KHÔNG thấy dòng "Enter a value:" hiện ra thì vẫn cứ
  gõ `yes` + Enter (prompt đôi khi bị đệm ở pipe). Đừng tưởng treo.
- "Không thao tác tay giữa hai lệnh" nghĩa là **không sửa Portal/CLI tay**;
  gõ `yes` xác nhận là bình thường.

```bash
cd ~/"Màn hình nền"/devops_vsf         # từ bản main sạch, git status trống
mkdir -p evidence/raw
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# 0. Xác nhận điểm xuất phát: RG không tồn tại, state rỗng
az group show -n rg-vsf-dev 2>&1 | head -1     # phải báo ResourceGroupNotFound
terraform -chdir=infra/app init -backend-config=backend.hcl
terraform -chdir=infra/app state list          # phải không in gì

# 1. Apply từ rỗng (~10-15 phút) — gõ yes 2 lần
make up 2>&1 | tee evidence/raw/m8-apply-$(date +%F).log

# 2. Bảng kiểm tra sau apply — CHẠY TỪNG LỆNH, ĐIỀN KẾT QUẢ THẬT vào evidence/M8.md
#    (tên resource có hậu tố NGẪU NHIÊN mỗi lần apply — lấy từ output, đừng copy tên cũ)
make outputs
curl -s -o /dev/null -w "production: %{http_code}\n" $(terraform -chdir=infra/app output -raw app_url)
curl -s -o /dev/null -w "staging:    %{http_code}\n" $(terraform -chdir=infra/app output -raw staging_url)
az acr show -n $(terraform -chdir=infra/app output -raw acr_name) --query adminUserEnabled -o tsv   # phải false
az keyvault show -n $(terraform -chdir=infra/app output -raw key_vault_name) --query properties.enableRbacAuthorization -o tsv   # phải true
az keyvault secret list --vault-name $(terraform -chdir=infra/app output -raw key_vault_name) --query "[].name" -o tsv   # có mysql-admin-password
az mysql flexible-server firewall-rule list -g rg-vsf-dev -n $(terraform -chdir=infra/app output -raw mysql_fqdn | cut -d. -f1) -o tsv | wc -l   # = app_possible_outbound_ip_count
terraform -chdir=infra/app output app_possible_outbound_ip_count
APP=app-vsf-$(terraform -chdir=infra/app output -raw name_suffix)
az webapp identity show -g rg-vsf-dev -n $APP --slot staging --query type -o tsv   # slot staging có identity (UserAssigned)
terraform -chdir=infra/app plan -no-color      # PHẢI ra "No changes"

# 3. Destroy (~30-40 phút — custom role definition xoá rất chậm, đã đo 25 phút
#    ở D9, KHÔNG phải treo) — gõ yes 1 lần
make down 2>&1 | tee evidence/raw/m8-destroy-$(date +%F).log

# 4. Xác nhận sạch (chụp màn hình 2 chỗ này cho evidence)
az group show -n rg-vsf-dev 2>&1 | head -1     # ResourceGroupNotFound
az keyvault list-deleted -o table              # không có kv-vsf-* (đã purge_on_destroy)
make check-empty
```

**Trong lúc GATE chạy: KHÔNG push/mở PR mới.** CI job `terraform-plan` cũng
lấy lock state — PR mở giữa chừng sẽ đỏ vì đụng lock (đã gặp ở D9, không phải
lỗi code; re-run job sau khi xong là được).

**Thời gian + hạn token:** tổng ~50-60 phút. Token `az` refresh tự động nên
thường không sao; nếu `terraform` báo lỗi auth giữa chừng → `az login` lại rồi
chạy tiếp (KHÔNG destroy/apply lại từ đầu nếu chưa cần).

**Lưu ý riêng cho repo này (khác guide gốc D9 viết lúc chưa biết throttle):**
- `make up` giờ deploy **2 vùng**: App/ACR/KV ở `centralindia`, MySQL ở
  `southeastasia` (`var.location` / `var.db_location` trong `variables.tf`).
  Nếu GATE này bị 429 lại (ít khả năng vì đã đổi vùng, nhưng nếu Azure đổi ý)
  — đọc lại `notes/d9.md` mục "Giải quyết cuối cùng: đổi region" trước khi
  hoảng, đừng tự ý đổi vùng lần nữa mà không hiểu vì sao.
- Tên resource random mỗi lần `apply` mới (suffix từ `random_string.suffix`)
  — lệnh ở bước 4 phải lấy tên THẬT từ `terraform output`, không copy tên cũ
  (`87z87q`) vì suffix sẽ khác sau khi destroy/apply lại.

## 3. Bảng kiểm tra sau apply (điền vào `evidence/M8.md`)

| Kiểm tra | Kết quả (điền khi chạy thật) |
|---|---|
| URL app trả 200 (placeholder) | |
| ACR admin disabled | |
| KV có secret, RBAC mode | |
| Firewall MySQL = số possible outbound IPs | |
| Slot staging có identity | |
| `plan` ngay sau apply → No changes | |

Tham khảo: **lần chạy 2026-09-20** (không phải bằng chứng GATE — GATE cần
chạy MỚI, không thao tác tay giữa 2 lệnh) đã cho: production/staging 200,
ACR `adminUserEnabled=false`, KV `enableRbacAuthorization=true`, firewall
18=18, `plan` lần 2 No changes. Nếu GATE thật ra số khác — đó là tín hiệu
thật, đừng sửa cho khớp số cũ.

## 4. `evidence/M8.md` — khung điền

```markdown
# M8 — Terraform toàn bộ hạ tầng

Ngày: <điền> · commit SHA của main: <git rev-parse --short HEAD>
Lệnh: make down → make up (không thao tác tay giữa hai lệnh)
Log: evidence/raw/m8-destroy-<ngày>.log, evidence/raw/m8-apply-<ngày>.log
Thời gian: destroy <?> phút · apply <?> phút

## Bảng kiểm tra sau apply
(dán bảng mục 3 đã điền)

## Ngoại lệ có chủ đích
infra/bootstrap KHÔNG nằm trong destroy — chứa storage account giữ state
Terraform của infra/app; nếu destroy luôn bootstrap, Terraform xoá đúng nơi
chứa state của chính nó (quyết định D7).

## Lỗi gặp và cách sửa
(nếu GATE lần này sạch — ghi "không gặp lỗi". Nếu gặp — link known-issues.md)
```

## 5. Trả lời mentor — bản nháp theo đúng repo này

Đọc hiểu, KHÔNG học thuộc — mentor sẽ hỏi biến thể, phải tự diễn đạt lại được.

**State là gì? Mất thì sao?**
File JSON ánh xạ "tên resource trong code" ↔ "ID resource thật trên Azure".
Không có nó, Terraform coi mọi thứ trong code là *chưa tồn tại* → apply lại
sẽ cố **tạo trùng** (và thường lỗi "name already exists" vì tên đã bị chiếm
trên Azure thật). Repo này giữ state trong Storage Account `stvsftffxqfgb`
(bootstrap, `southeastasia`) với `versioning_enabled = true` — mất/hỏng thì
khôi phục bằng version cũ của blob, hoặc `terraform import` từng resource
nếu blob mất hẳn.

**Lock là gì? Thực tế trên Azure ra sao?**
Cơ chế chặn 2 tiến trình `apply`/`plan` cùng ghi state 1 lúc — không có lock
thì 2 apply song song có thể ghi đè state lẫn nhau, làm state sai lệch với
thực tế. Ở đây hiện thực bằng **blob lease** của Azure Storage: `apply` lấy
lease trên `app.tfstate` trước khi ghi, tiến trình thứ 2 gọi cùng lúc bị từ
chối với "state blob is already locked" kèm Lock ID. Đã tự gặp thật ở D9:
`terraform apply` bị lỗi mạng giữa lúc release lock → lock kẹt lại → phải
`terraform force-unlock <ID>` (chỉ an toàn vì biết chắc lock đó là của chính
mình, không phải người khác đang chạy).

**Dependency ngầm vs tường minh? Ví dụ trong repo?**
Ngầm: Terraform tự suy ra thứ tự khi resource A **tham chiếu thuộc tính**
của resource B trong code (vd `azurerm_key_vault_secret.mysql_admin_password`
tham chiếu `azurerm_key_vault.kv.id` → tự biết phải tạo KV trước). Tường
minh: khai `depends_on` khi có phụ thuộc KHÔNG thể hiện qua tham chiếu thuộc
tính — ví dụ `mysql_admin_password` còn `depends_on =
[azurerm_role_assignment.kv_secrets_officer_operator]`: việc ghi secret cần
role đã gán VÀ đã lan truyền, nhưng code không "đọc" giá trị nào từ role
assignment đó, nên nếu không khai `depends_on` tường minh, Terraform có thể
tạo secret trước khi role kịp lan truyền → 403.

**Vì sao bootstrap tách riêng?**
`infra/bootstrap` chứa chính storage account đang giữ state của `infra/app`.
Nếu gộp chung, `destroy` hằng ngày của `infra/app` sẽ xoá luôn nơi lưu state
của chính nó — vòng lặp không giải quyết được. Bootstrap sống lâu dài, không
nằm trong nhịp destroy/apply mỗi buổi.

**Vì sao apply 2 pha?**
Firewall MySQL dùng `for_each` trên `possible_outbound_ip_address_list` của
Web App — giá trị này **chỉ có sau khi Web App tồn tại**. Lúc `apply` từ
state rỗng, Terraform chưa biết Web App sẽ có IP nào nên không tính được tập
khoá của `for_each` → lỗi "Invalid for_each argument". Pha 1 tạo riêng Web
App (`-target`) để biết IP, pha 2 apply toàn bộ phần còn lại khi IP đã có
trong state.

**Terraform và CD cùng sửa Web App thì sao?**
Chia rõ ai sở hữu thuộc tính nào: Terraform sở hữu mọi thứ của Web App **trừ**
tag image (`lifecycle { ignore_changes = [...docker_image_name] }`, thêm ở
D9); CD (D16) sở hữu tag image, đổi trực tiếp trên Azure không qua Terraform.
Không có `ignore_changes`, mỗi lần Terraform apply sẽ thấy image trên Azure
khác `var.placeholder_image` trong code và **đảo ngược** bản đang chạy về
placeholder.

**Secret nằm ở đâu trong state?**
`random_password.mysql_admin.result` và giá trị `azurerm_key_vault_secret`
đều nằm **rõ ràng, không mã hoá** trong `app.tfstate` — thuộc tính `sensitive`
của Terraform chỉ giấu khỏi output CLI (`plan`/`apply`), không mã hoá trong
file state. Vì vậy storage chứa state phải khoá quyền chặt: đã tắt shared
key (`shared_access_key_enabled = false`), chỉ Entra ID + RBAC được đọc/ghi.

## Xong khi
- [ ] 2 log thô (`evidence/raw/m8-destroy-*.log`, `m8-apply-*.log`)
- [ ] Bảng kiểm tra đầy đủ, số thật (không copy từ lần chạy tham khảo)
- [ ] `evidence/M8.md` viết xong
- [ ] Trả lời trôi 7 câu hỏi — tự nói được, không đọc
- [ ] Resource đã `down` sau khi xong (không để qua đêm)

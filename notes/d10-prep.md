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
      có gì uncommitted) trước khi chạy `make down` đầu tiên.
- [ ] Không có resource tạo tay nào trong `rg-vsf-dev` (D9 không dùng Portal
      tay lần nào — chỉ 1 lần thử tạo/xoá App Service Plan tay để chẩn đoán
      429, đã xoá sạch ngay).

## 2. Lệnh chạy + log thô

**Quan trọng:** dùng `tee` để vừa xem output vừa ghi log, KHÔNG copy tay:

```bash
mkdir -p evidence/raw
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# 1. Destroy — log kèm timestamp
make down 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee evidence/raw/m8-destroy-$(date +%F).log
# (nếu chưa có lệnh `ts`: sudo apt install moreutils — hoặc bỏ qua `ts`,
#  terraform tự in đủ "Xm Ys elapsed" trong log rồi)

# 2. Verify Portal: rg-vsf-dev không tồn tại, Key Vault không còn trong
#    "Deleted vaults" (đã purge — chụp màn hình 2 chỗ này)
az group show -n rg-vsf-dev   # phải báo ResourceGroupNotFound
az keyvault list-deleted -o table   # không có kv-vsf-* nào (đã purge_on_destroy)

# 3. Apply lại từ đầu — log kèm timestamp
make up 2>&1 | tee evidence/raw/m8-apply-$(date +%F).log

# 4. Bảng kiểm tra sau apply — CHẠY TỪNG LỆNH, ĐIỀN KẾT QUẢ THẬT vào evidence/M8.md
terraform -chdir=infra/app output app_url
curl -s -o /dev/null -w "%{http_code}\n" $(terraform -chdir=infra/app output -raw app_url)
az acr show -n <acr_name_output> --query adminUserEnabled -o tsv        # phải false
az keyvault show -n <kv_name_output> --query properties.enableRbacAuthorization -o tsv  # phải true
az mysql flexible-server firewall-rule list -g rg-vsf-dev -n <mysql_name> -o tsv | wc -l  # = app_possible_outbound_ip_count
az resource list -g rg-vsf-dev --query "[?contains(type,'sites/slots')].identity" -o table  # slot staging có identity
terraform -chdir=infra/app plan -no-color   # PHẢI ra "No changes"

# 5. Destroy lần nữa — không để qua đêm
make down 2>&1 | tee evidence/raw/m8-destroy-final-$(date +%F).log
```

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

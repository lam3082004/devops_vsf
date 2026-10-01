# Rollback và phục hồi

Bốn kịch bản đã chạy thật, mỗi dòng có thời gian đo được. Cách xác nhận sự cố trước khi chọn kịch bản:
[`runbook.md`](../runbook.md). Môi trường mẫu: suffix `jcip0s` (thay bằng `terraform -chdir=infra/app output -raw name_suffix`).

| # | Tình huống | Cách phục hồi | Thời gian đo | Bằng chứng |
|---|---|---|---|---|
| 1 | **Bản mới lỗi đã lên production** (CD xanh nhưng app sai) | swap ngược slot | bản thân swap 39 giây · RTO drill 12 phút 39 giây (gồm 7 phút chờ người có quyền) | drill 2 [`drills/2026-10-01-bad-deploy.md`](drills/2026-10-01-bad-deploy.md) · rollback tự động của CD: [`evidence/M10.md`](../evidence/M10.md) C4 |
| 2 | **Hạ tầng bị sửa tay (drift)**, ví dụ mất rule firewall MySQL | `terraform plan` → `apply` | 15 s từ apply tới hồi phục · MTTR 10 phút 58 giây | drill 1 [`drills/2026-10-01-firewall.md`](drills/2026-10-01-firewall.md) |
| 3 | **Mất quyền Key Vault** của managed identity | `terraform apply` (tạo lại role) → restart | role tạo lại 29 s + lan truyền RBAC + restart (không đo tổng) | [`evidence/M5.md`](../evidence/M5.md) bước 8–11 |
| 4 | **Mất máy / mất checkout** (cần dựng lại từ repo) | clone mới → khôi phục state bootstrap từ bản sao lưu → `plan` → `make up` | clone 05:51:33 → `make up` xong 06:01:31 = 10 phút (gồm cả sửa README giữa chừng); riêng `make up` 0 thay đổi: 1 phút 50 giây | [`evidence/M8.md`](../evidence/M8.md) mục Lần cuối · README §2 |
| — | Mất cả môi trường (`rg-vsf-dev`) | `make up` từ rỗng | 24 phút 27 giây (D10, 36 resource) | [`evidence/M8.md`](../evidence/M8.md) |
| — | MySQL point-in-time restore | **không làm** | — | xem cuối file |

## 1. Swap ngược (bản mới lỗi)

Slot `staging` luôn giữ bản **trước** của lần swap gần nhất, nên rollback = swap lần nữa. Chỉ app nào lỗi thì swap
app đó; lỗi cả hai thì swap `fe` trước `be` (thứ tự ngược với CD).

```bash
az webapp deployment slot swap -g rg-vsf-dev -n app-vsf-<s> --slot staging --target-slot production   # be
curl -4 -s https://app-vsf-<s>.azurewebsites.net/version     # phải ra SHA cũ
```

Sau đó **bắt buộc** mở PR revert và merge, nếu không lần CD tiếp theo sẽ đẩy bản lỗi (đang nằm ở staging) trở lại
production. Sticky setting (`API_BASE_URL` của `fe`) không đi theo swap, nên `plan` sau swap vẫn No changes (D17).

## 2. Drift → apply

```bash
make plan           # thấy đúng resource bị thiếu/lệch, KHÔNG có destroy ngoài dự kiến
terraform -chdir=infra/app apply   # chỉ khi plan đúng như chẩn đoán
make plan           # No changes
```

Bài học drill 1: drift firewall **không** làm app lỗi ngay. Pool connection giữ connection cũ tới khi restart hoặc
scale-out, nên phải chạy `plan` để thấy, đừng chờ alert.

## 3. Khôi phục quyền Key Vault

`terraform apply` (không `-var grant_app_keyvault_access=false`) → chờ RBAC lan truyền vài phút → `az webapp restart`.
Key Vault reference chỉ resolve lúc container khởi động, nên trả quyền mà không restart thì app vẫn đứng.

## 4. Dựng lại từ clone mới

README §2 (khung "Bootstrap đã có sẵn"): khôi phục `infra/bootstrap/terraform.tfstate` từ `~/vsf-state-backup/`, rồi
`plan` cả hai root phải ra No changes **trước** khi apply bất cứ gì. Mất cả bản sao lưu: import lại như D23
(`notes/d23.md`), cẩn thận `random_string.suffix` (`ai-failure-log.md` #43).

## Không làm: MySQL point-in-time restore

PITR của Flexible Server tạo **server mới** (tên mới, firewall/app settings phải trỏ lại), mất thời gian dựng như một server mới (chưa đo) và tính
tiền thêm một server trong lúc tồn tại. Dữ liệu trong bài là ticket thử nên giá trị kiểm thử thấp hơn chi phí. Backup
tự động vẫn bật, nhưng `backup_retention_days = 1` (mức tối thiểu để tiết kiệm, `infra/app/db.tf`) nên chỉ lùi được
tối đa 1 ngày. Nếu cần: `az mysql flexible-server restore --restore-time …`,
rồi đổi `DB_HOST` qua Terraform.

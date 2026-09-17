# Thông số backend cho infra/app. File này KHÔNG chứa bí mật (không có access key,
# vì xác thực bằng Entra ID) nên commit được.
# Dùng: terraform -chdir=infra/app init -backend-config=backend.hcl
resource_group_name  = "rg-vsf-bootstrap"
storage_account_name = "stvsftffxqfgb"
container_name       = "tfstate"
key                  = "app.tfstate"
use_azuread_auth     = true

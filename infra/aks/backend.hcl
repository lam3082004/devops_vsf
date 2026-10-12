# Thông số backend cho infra/aks. CÙNG storage account + container với infra/app,
# KHÁC key: hai state độc lập, `make aks-down` không chạm app.tfstate.
# File này KHÔNG chứa bí mật (xác thực bằng Entra ID) nên commit được.
# Dùng: terraform -chdir=infra/aks init -backend-config=backend.hcl
resource_group_name  = "rg-vsf-bootstrap"
storage_account_name = "stvsftffxqfgb"
container_name       = "tfstate"
key                  = "aks.tfstate"
use_azuread_auth     = true

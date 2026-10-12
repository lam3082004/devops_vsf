terraform {
  # Để rỗng có chủ đích, giống infra/app/backend.tf: giá trị truyền lúc init qua
  # -backend-config=backend.hcl.
  backend "azurerm" {}
}

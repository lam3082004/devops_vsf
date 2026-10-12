# infra/aks — phần ADVANCED, ngoài phạm vi topic.md (M1–M11, S1–S3).
#
# Đích deploy THỨ HAI cho cùng app OpsBoard, chạy song song với App Service của
# infra/app. Nguyên tắc của root này: CHỈ THÊM. Nó đọc ACR / Key Vault / MySQL /
# action group của infra/app bằng data source theo tên (mẫu keyvault.tf của infra/app,
# không terraform_remote_state — quyết định D7) và chỉ tạo resource CON mới trên đó
# (1 role AcrPull, 1 database + 1 firewall rule, 1 secret + 3 role scope secret).
#
# Thứ tự vòng đời: `make up` (infra/app) → `make aks-up`; `make aks-down` → `make down`.
# Đảo thứ tự destroy thì state của root này mồ côi.

data "azurerm_client_config" "current" {}

# Tìm ACR của môi trường nền để suy ra hậu tố (locals.tf).
data "azurerm_resources" "base_acr" {
  resource_group_name = local.base_rg
  type                = "Microsoft.ContainerRegistry/registries"
}

data "azurerm_container_registry" "base" {
  name                = "acr${var.project}${local.name_suffix}"
  resource_group_name = local.base_rg
}

data "azurerm_key_vault" "base" {
  name                = "kv-${var.project}-${local.name_suffix}"
  resource_group_name = local.base_rg
}

data "azurerm_mysql_flexible_server" "base" {
  name                = "mysql-${var.project}-${local.name_suffix}-sea"
  resource_group_name = local.base_rg
}

resource "azurerm_resource_group" "aks" {
  name     = "rg-${var.project}-aks"
  location = var.location
  tags     = local.tags

  lifecycle {
    precondition {
      condition     = length(data.azurerm_resources.base_acr.resources) == 1
      error_message = "Không tìm thấy đúng một ACR trong RG của infra/app. Dựng môi trường nền trước (make up) rồi mới make aks-up."
    }
  }
}

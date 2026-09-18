# Container Registry — nơi CD (D16) push image, app pull bằng managed identity.
#
# admin_enabled = false: pull KHÔNG dùng username/password admin của ACR (đó là
# một secret tĩnh, không xoay vòng được) — dùng AcrPull gán cho chính managed
# identity của Web App (identity.tf), khớp M1.
resource "azurerm_container_registry" "acr" {
  # Tên ACR chỉ được chữ thường + số, không được gạch nối như các resource khác.
  name                = "acr${var.project}${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# Cho phép danh tính của app (identity.tf) pull image từ ACR này.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

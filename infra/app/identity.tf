# Danh tính của app, dùng chung cho production và slot staging.
#
# Vì sao user-assigned chứ không phải system-assigned: system identity gắn với
# từng slot, khi swap code đi sang slot kia nhưng danh tính KHÔNG đi theo →
# quyền AcrPull / Key Vault cấp cho slot staging không còn đúng sau swap.
# Một identity chung cho cả hai slot thì swap không đổi danh tính.
#
# Các giá trị output dùng ở đâu:
#   id           → gắn vào Web App/slot (khối identity) và key_vault_reference_identity_id (D12)
#   client_id    → container_registry_managed_identity_client_id để pull ACR (D11)
#   principal_id → principal của role assignment AcrPull (D9), Key Vault Secrets User (D9)
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project}-app-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = local.tags
}

# Danh tính RIÊNG của `fe` (review 30/09 #2, người dùng duyệt 01/10). Trước đây `fe` dùng chung
# `app` với `be` → có Key Vault Secrets User trên CẢ vault, tức một lỗ RCE/SSRF ở `fe` (Next.js)
# lấy token IMDS là đọc được mật khẩu admin MySQL — trái với ý đồ "fe không giữ secret DB".
# `fe` chỉ cần: AcrPull (acr.tf) + đọc ĐÚNG một secret appinsights (keyvault.tf, scope secret).
# Chung cho site + slot staging, cùng lý do user-assigned ở trên.
resource "azurerm_user_assigned_identity" "fe" {
  name                = "id-${var.project}-fe-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = local.tags
}

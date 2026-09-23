output "resource_group_name" {
  description = "RG của môi trường app. Mọi resource từ D8 nằm trong đây."
  value       = azurerm_resource_group.app.name
}

output "location" {
  value = azurerm_resource_group.app.location
}

output "name_suffix" {
  description = "Hậu tố dùng cho các tên phải duy nhất toàn cầu."
  value       = local.name_suffix
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "staging_url" {
  value = "https://${azurerm_linux_web_app_slot.staging.default_hostname}"
}

output "fe_url" {
  value = "https://${azurerm_linux_web_app.fe.default_hostname}"
}

output "fe_staging_url" {
  value = "https://${azurerm_linux_web_app_slot.fe_staging.default_hostname}"
}

output "app_possible_outbound_ip_count" {
  description = "Phải bằng số firewall rule MySQL (M3)."
  value       = length(azurerm_linux_web_app.app.possible_outbound_ip_address_list)
}

output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.db.fqdn
}

output "mysql_database_name" {
  value = azurerm_mysql_flexible_database.app.name
}

output "app_identity_id" {
  description = "Resource ID — gắn vào Web App/slot, key_vault_reference_identity_id."
  value       = azurerm_user_assigned_identity.app.id
}

output "app_identity_client_id" {
  description = "Client ID — dùng khi pull ACR bằng managed identity (D11)."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "app_identity_principal_id" {
  description = "Principal ID — dùng cho role assignment (AcrPull, Key Vault Secrets User)."
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "acr_login_server" {
  description = "Registry để docker build/push (D11), vd acrvsfxxxxxx.azurecr.io."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "key_vault_uri" {
  description = "Dùng trong @Microsoft.KeyVault(SecretUri=...) của app settings (D12)."
  value       = azurerm_key_vault.kv.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

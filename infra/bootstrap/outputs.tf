output "resource_group_name" {
  description = "RG chứa state storage. Dùng cho backend của infra/app."
  value       = azurerm_resource_group.bootstrap.name
}

output "storage_account_name" {
  description = "Tên storage account chứa tfstate."
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "backend_config_hint" {
  description = "Giá trị để điền vào backend của infra/app."
  value = {
    resource_group_name  = azurerm_resource_group.bootstrap.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    key                  = "app.tfstate"
    use_azuread_auth     = true
  }
}

output "gh_plan_client_id" {
  description = "Client ID của id-gh-plan → GitHub Variable AZURE_CLIENT_ID_PLAN."
  value       = azurerm_user_assigned_identity.gh_plan.client_id
}

output "gh_deploy_client_id" {
  description = "Client ID của id-gh-deploy → GitHub Variable AZURE_CLIENT_ID_DEPLOY."
  value       = azurerm_user_assigned_identity.gh_deploy.client_id
}

output "tenant_id" {
  description = "Tenant ID → GitHub Variable AZURE_TENANT_ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Subscription ID → GitHub Variable AZURE_SUBSCRIPTION_ID."
  value       = data.azurerm_client_config.current.subscription_id
}

output "agent_triage_client_id" {
  description = "Client ID của id-agent-triage → GitHub Variable AZURE_AGENT_CLIENT_ID (D23)."
  value       = azurerm_user_assigned_identity.agent_triage.client_id
}

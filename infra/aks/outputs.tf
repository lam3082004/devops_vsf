# Output của root này là ĐẦU VÀO của scripts/aks-render.sh: mọi giá trị riêng môi trường
# (client id, tenant, tên vault, IP) đi từ đây vào manifest lúc deploy, không nằm trong git.

output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "node_resource_group_name" {
  description = "RG do AKS quản (VMSS, load balancer, public IP)."
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "name_suffix" {
  description = "Hậu tố của môi trường nền (infra/app) mà cluster này đang nối vào."
  value       = local.name_suffix
}

output "k8s_namespace" {
  value = local.k8s_namespace
}

output "tenant_id" {
  description = "Dùng trong SecretProviderClass."
  value       = data.azurerm_client_config.current.tenant_id
}

output "be_identity_client_id" {
  description = "Annotation azure.workload.identity/client-id của ServiceAccount be."
  value       = azurerm_user_assigned_identity.be.client_id
}

output "fe_identity_client_id" {
  description = "Annotation azure.workload.identity/client-id của ServiceAccount fe."
  value       = azurerm_user_assigned_identity.fe.client_id
}

output "key_vault_name" {
  value = data.azurerm_key_vault.base.name
}

output "mysql_secret_name" {
  value = local.mysql_secret_name
}

output "appinsights_secret_name" {
  value = local.appinsights_secret_name
}

output "acr_login_server" {
  value = data.azurerm_container_registry.base.login_server
}

output "mysql_fqdn" {
  value = data.azurerm_mysql_flexible_server.base.fqdn
}

output "mysql_admin_login" {
  value = data.azurerm_mysql_flexible_server.base.administrator_login
}

output "mysql_database_name" {
  value = azurerm_mysql_flexible_database.aks.name
}

output "aks_outbound_ip" {
  description = "Phải bằng firewall rule aks-outbound của MySQL (M3)."
  value       = data.azurerm_public_ip.aks_outbound.ip_address
}

output "allowed_cidrs" {
  description = "loadBalancerSourceRanges của Service fe. Rỗng = mở ra Internet (xem variables.tf)."
  value       = local.allowed_cidrs
  # IP cá nhân: `terraform apply`/`output` in mọi output không sensitive ra màn hình và
  # ra log bằng chứng (review 12/10 #1). scripts/aks-render.sh đọc bằng `output -json`.
  sensitive = true
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.aks.name
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace ID dùng cho truy vấn KQL qua API."
  value       = azurerm_log_analytics_workspace.aks.workspace_id
}

output "app_insights_name" {
  value = azurerm_application_insights.aks.name
}

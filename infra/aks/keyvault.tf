# Quyền đọc secret cho workload trên AKS (tương đương M4/M5) — trên VAULT của infra/app.
#
# Scope là TỪNG SECRET, không phải vault (mẫu kv_secrets_user_fe_appinsights của
# infra/app/keyvault.tf). ID của secret dựng tay từ ID vault + tên: root này không đọc
# GIÁ TRỊ secret MySQL nên mật khẩu không chui vào aks.tfstate.
#
# count: tắt bằng -var 'grant_aks_keyvault_access=false' để đo M5 — pod mới không mount
# được volume CSI và kẹt ở ContainerCreating (FailedMount). Xem variables.tf.

locals {
  mysql_secret_scope       = "${data.azurerm_key_vault.base.id}/secrets/${local.mysql_secret_name}"
  appinsights_secret_scope = "${data.azurerm_key_vault.base.id}/secrets/${local.appinsights_secret_name}"
}

resource "azurerm_role_assignment" "be_mysql_secret" {
  count = var.grant_aks_keyvault_access ? 1 : 0

  scope                = local.mysql_secret_scope
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.be.principal_id
}

resource "azurerm_role_assignment" "be_appinsights_secret" {
  count = var.grant_aks_keyvault_access ? 1 : 0

  scope                = local.appinsights_secret_scope
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.be.principal_id

  # Secret phải tồn tại trước khi gán role ở scope của nó.
  depends_on = [azurerm_key_vault_secret.appinsights_connection_string]
}

# `fe` chỉ đọc đúng secret App Insights — không có quyền gì trên secret MySQL.
resource "azurerm_role_assignment" "fe_appinsights_secret" {
  count = var.grant_aks_keyvault_access ? 1 : 0

  scope                = local.appinsights_secret_scope
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.fe.principal_id

  depends_on = [azurerm_key_vault_secret.appinsights_connection_string]
}

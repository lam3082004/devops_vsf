# Tenant của phiên đang chạy Terraform — Key Vault cần tenant_id tường minh.
data "azurerm_client_config" "current" {}

# id-gh-plan sống trong infra/bootstrap — state KHÁC với infra/app (quyết định
# D7: bootstrap không nằm trong vòng destroy hằng ngày). Tra bằng data source
# theo tên thay vì terraform_remote_state để 2 state không phụ thuộc lẫn nhau.
data "azurerm_user_assigned_identity" "gh_plan" {
  name                = "id-gh-plan"
  resource_group_name = "rg-vsf-bootstrap"
}

resource "azurerm_key_vault" "kv" {
  name                = "kv-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC thay vì access policy — nhất quán với cách cấp quyền cho mọi resource
  # khác trong repo này.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  # Tắt purge protection: D10 (GATE) cần destroy → apply lại CÙNG TÊN vault.
  # Bật purge protection thì soft-deleted vault chặn apply lại cho tới khi hết
  # retention hoặc purge tay — không hợp với vòng đời "xoá cuối buổi" của môi
  # trường dev này.
  purge_protection_enabled = false

  tags = local.tags
}

# Terraform (chạy bằng tài khoản bạn) cần ghi được secret vào vault.
# principal_id PIN CỨNG (var.secrets_writer_object_id), KHÔNG dùng
# data.azurerm_client_config.current.object_id — xem giải thích ở variables.tf.
resource "azurerm_role_assignment" "kv_secrets_officer_operator" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.secrets_writer_object_id
}

# App đọc secret lúc chạy (Key Vault reference trong app settings, D12).
# count: tắt bằng -var 'grant_app_keyvault_access=false' để đo M5 (app mất quyền
# đọc vault → Key Vault reference đỏ → app gãy sau khi restart). Xem variables.tf.
resource "azurerm_role_assignment" "kv_secrets_user_app" {
  count = var.grant_app_keyvault_access ? 1 : 0

  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# id-gh-plan cần đọc secret để `terraform plan` không báo lệch state khi có
# secret data source khác tham chiếu tới giá trị trong vault (và để job
# terraform-plan trong CI không bị 403 khi refresh).
resource "azurerm_role_assignment" "kv_secrets_user_gh_plan" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.gh_plan.principal_id
}

# Mật khẩu MySQL (random_password ở db.tf) — nằm trong vault thay vì chỉ nằm
# trong state, chuẩn bị cho M4/M5 (D12: app đọc qua Key Vault reference).
resource "azurerm_key_vault_secret" "mysql_admin_password" {
  name         = "mysql-admin-password"
  value        = random_password.mysql_admin.result
  key_vault_id = azurerm_key_vault.kv.id

  # Phải tạo SAU khi role Secrets Officer đã gán xong — ghi secret là quyền
  # data-plane, cần role đã lan truyền. Thiếu depends_on này, apply lần đầu
  # có thể vào đúng lúc quyền chưa kịp lan truyền → 403 Forbidden (xem Bẫy ở
  # guide D9, notes/d9.md sẽ ghi lại nếu gặp thật).
  depends_on = [azurerm_role_assignment.kv_secrets_officer_operator]
}

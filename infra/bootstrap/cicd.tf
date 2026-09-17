# Danh tính cho GitHub Actions.
#
# Vì sao là user-assigned managed identity chứ không phải app registration:
# tenant VINACADEMY LLC đặt allowedToCreateApps = false (kiểm chứng ngày 15/09
# qua Graph API), user thường KHÔNG tạo được app registration. Managed identity
# chỉ cần quyền RBAC trên subscription — thứ mình đang có với vai trò Owner.
#
# Hai danh tính tách riêng để giữ least privilege: CI chạy trên PR chỉ cần đọc,
# CD chạy trên main mới được ghi (role của deploy thêm ở D16).

resource "azurerm_user_assigned_identity" "gh_plan" {
  name                = "id-gh-plan"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "ci-plan" })
}

resource "azurerm_user_assigned_identity" "gh_deploy" {
  name                = "id-gh-deploy"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "cd-deploy" })
}

# ---------- Federated credentials ----------
# GitHub cấp cho mỗi lần chạy workflow một token có chữ ký; Entra tin token đó
# nếu "subject" khớp đúng chuỗi khai báo dưới. Không có client secret nào.
#
# subject là thứ bảo đảm "chỉ main mới deploy được" NGAY Ở TẦNG DANH TÍNH:
# token sinh từ pull_request mang subject khác, Entra sẽ từ chối.

locals {
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "gh_plan_pr" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_plan.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:pull_request"
}

resource "azurerm_federated_identity_credential" "gh_deploy_main" {
  name                = "github-main"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:ref:refs/heads/main"
}

# ---------- Quyền tối thiểu ----------

# CI chỉ cần ĐỌC trạng thái hạ tầng để chạy plan.
resource "azurerm_role_assignment" "gh_plan_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.gh_plan.principal_id
}

# Nhưng vẫn cần quyền GHI blob: `terraform plan` cũng lấy lease trên state,
# và lease là thao tác ghi. Chỉ cấp ở đúng storage account chứa state.
resource "azurerm_role_assignment" "gh_plan_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_plan.principal_id
}

# CD cũng cần đọc/ghi state để apply. Các quyền tạo resource (AcrPush,
# Website Contributor, ...) sẽ thêm ở D16 khi dựng pipeline CD.
resource "azurerm_role_assignment" "gh_deploy_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_deploy.principal_id
}

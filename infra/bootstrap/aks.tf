# Phần ADVANCED (AKS, ngoài topic.md) — danh tính cho .github/workflows/cd-aks.yml.
#
# Danh tính RIÊNG, không dùng id-gh-deploy: CD của App Service và CD của AKS thu hồi,
# soi nhật ký tách bạch, và id-gh-deploy không nhận thêm quyền nào vì bài advanced này.
#
# Khai ở BOOTSTRAP, mẫu agent.tf: client id cố định qua các vòng `make aks-down`/`aks-up`
# → biến GitHub AZURE_CLIENT_ID_AKS_DEPLOY chỉ set một lần. Quyền trên cluster khai ở
# infra/aks/deploy-permissions.tf: cluster tắt thì quyền mất theo.

resource "azurerm_user_assigned_identity" "gh_aks_deploy" {
  name                = "id-gh-aks-deploy"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "cd-aks-deploy" })
}

# Chỉ tin token của job khai `environment: aks-deploy` (environment đó chỉ nhận `main`).
# Không có credential dạng `ref:refs/heads/...` hay `pull_request`. Cả dạng tên lẫn dạng
# immutable, cùng lý do với cicd.tf.
resource "azurerm_federated_identity_credential" "gh_aks_deploy_env" {
  name                = "github-env-aks-deploy"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_aks_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:environment:aks-deploy"
}

resource "azurerm_federated_identity_credential" "gh_aks_deploy_env_immutable" {
  name                = "github-env-aks-deploy-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_aks_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:environment:aks-deploy"
}

# Quyền DUY NHẤT sống ở bootstrap: biết cluster có tồn tại hay không. Thiếu nó thì khi
# cluster đã `make aks-down`, cd-aks.yml không phân biệt được "cluster tắt" (bỏ qua, xanh)
# với "mất quyền" (phải đỏ) — đúng lỗi nuốt lỗi `az` mà review 30/09 #4 bắt ở cd.yml.
# Một action đọc, không lộ cấu hình nào khác của subscription.
resource "azurerm_role_definition" "aks_presence_reader" {
  name  = "vsf-aks-presence-reader"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  permissions {
    actions     = ["Microsoft.ContainerService/managedClusters/read"]
    not_actions = []
  }

  assignable_scopes = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
}

resource "azurerm_role_assignment" "gh_aks_deploy_presence_reader" {
  scope              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_id = azurerm_role_definition.aks_presence_reader.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.gh_aks_deploy.principal_id
}

output "gh_aks_deploy_client_id" {
  description = "Client ID của id-gh-aks-deploy → GitHub Variable AZURE_CLIENT_ID_AKS_DEPLOY."
  value       = azurerm_user_assigned_identity.gh_aks_deploy.client_id
}

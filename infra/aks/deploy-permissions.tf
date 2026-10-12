# Quyền của id-gh-aks-deploy (.github/workflows/cd-aks.yml) trên cluster.
#
# Danh tính sống ở infra/bootstrap/aks.tf (client id cố định qua các vòng aks-down/aks-up,
# mẫu id-agent-triage); QUYỀN khai ở đây để sinh/mất cùng cluster.
#
# Hai custom role thay vì role built-in:
#   - "Azure Kubernetes Service Cluster Admin Role" là built-in duy nhất có runcommand
#     nhưng kèm listClusterAdminCredential;
#   - "Azure Kubernetes Service RBAC Writer" có secrets/* và pods/exec — CD sẽ đọc được
#     mật khẩu DB (Secret do CSI đồng bộ, hoặc `exec be -- env`).
# CD chỉ cần: đổi image của Deployment và xem rollout. Bước kiểm sau deploy dùng curl từ
# command pod (scripts/aks-cd.sh), không exec vào pod nào.
#
# Rủi ro CÒN LẠI, không gỡ được ở tầng role: `deployments/write` cho phép sửa cả pod
# template (lệnh, env), tức một workflow bị chiếm quyền vẫn tự chạy được code bằng danh
# tính của `be`. Data action của Azure không chia nhỏ tới "chỉ trường image" (known-issues.md).
data "azurerm_user_assigned_identity" "gh_aks_deploy" {
  name                = "id-gh-aks-deploy"
  resource_group_name = "rg-vsf-bootstrap"
}

# Control plane: chạy `az aks command invoke` (kubectl đi qua ARM, không cần IP runner
# nằm trong authorized_ip_ranges) và đọc kết quả.
resource "azurerm_role_definition" "aks_command_runner" {
  name  = "vsf-aks-command-runner"
  scope = azurerm_kubernetes_cluster.aks.id

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/runcommand/action",
      "Microsoft.ContainerService/managedClusters/commandResults/read",
    ]
    not_actions = []
  }

  assignable_scopes = [azurerm_kubernetes_cluster.aks.id]
}

resource "azurerm_role_assignment" "gh_aks_deploy_command_runner" {
  scope              = azurerm_kubernetes_cluster.aks.id
  role_definition_id = azurerm_role_definition.aks_command_runner.role_definition_resource_id
  principal_id       = data.azurerm_user_assigned_identity.gh_aks_deploy.principal_id
}

# Data plane: quyền Kubernetes, gán ở scope NAMESPACE của app — không chạm kube-system.
resource "azurerm_role_definition" "aks_app_deployer" {
  name  = "vsf-aks-app-deployer"
  scope = azurerm_kubernetes_cluster.aks.id

  permissions {
    actions     = []
    not_actions = []
    data_actions = [
      "Microsoft.ContainerService/managedClusters/apps/deployments/read",
      "Microsoft.ContainerService/managedClusters/apps/deployments/write",
      "Microsoft.ContainerService/managedClusters/apps/replicasets/read",
    ]
  }

  assignable_scopes = [azurerm_kubernetes_cluster.aks.id]
}

resource "azurerm_role_assignment" "gh_aks_deploy_app_deployer" {
  scope              = "${azurerm_kubernetes_cluster.aks.id}/namespaces/${local.k8s_namespace}"
  role_definition_id = azurerm_role_definition.aks_app_deployer.role_definition_resource_id
  principal_id       = data.azurerm_user_assigned_identity.gh_aks_deploy.principal_id
}

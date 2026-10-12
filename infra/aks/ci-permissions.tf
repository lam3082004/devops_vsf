# Quyền bổ sung cho id-gh-plan (CI) để `terraform plan` của root này refresh được cluster.
#
# Cùng loại bẫy với infra/app/ci-permissions.tf: provider đọc azurerm_kubernetes_cluster
# bằng cách gọi listClusterUserCredential (dạng "list…/action", Reader không có). Role
# built-in dưới đây chỉ có đúng action đó + read. Kubeconfig trả về KHÔNG chứa bí mật:
# tài khoản local đã tắt (cluster.tf), muốn dùng vẫn phải có token Entra và role data plane
# — thứ id-gh-plan không được cấp.
data "azurerm_user_assigned_identity" "gh_plan" {
  name                = "id-gh-plan"
  resource_group_name = "rg-vsf-bootstrap"
}

resource "azurerm_role_assignment" "gh_plan_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_user_assigned_identity.gh_plan.principal_id
}

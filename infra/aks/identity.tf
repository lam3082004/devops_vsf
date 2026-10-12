# Danh tính của workload trên AKS — tách `be` và `fe` như infra/app/identity.tf:
# `fe` không được chạm vào secret của DB.
#
# Khác App Service ở chỗ gắn danh tính: ở đó identity gắn vào Web App; ở đây pod chạy
# bằng một ServiceAccount, và federated credential dưới đây nói với Entra "token của
# service account <namespace>/<tên> trên cluster NÀY được đổi lấy token của identity này".
# Pod khác trên cùng node không dùng được danh tính này.

resource "azurerm_user_assigned_identity" "be" {
  name                = "id-${var.project}-aks-be-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "fe" {
  name                = "id-${var.project}-aks-fe-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  tags                = local.tags
}

# subject phải khớp TỪNG KÝ TỰ với namespace + tên ServiceAccount trong
# k8s/base/serviceaccounts.yaml — lệch là pod nhận AADSTS70021, mount secret thất bại.
resource "azurerm_federated_identity_credential" "be" {
  name                = "aks-${local.k8s_namespace}-be"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.be.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${local.k8s_namespace}:be"
}

resource "azurerm_federated_identity_credential" "fe" {
  name                = "aks-${local.k8s_namespace}-fe"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.fe.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${local.k8s_namespace}:fe"
}

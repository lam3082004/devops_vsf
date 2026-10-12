# Pull image từ ACR của infra/app bằng managed identity (tương đương M1).
#
# Người pull là KUBELET identity (danh tính của node, AKS tự tạo trong node RG), không
# phải identity của workload ở identity.tf. Manifest không có imagePullSecrets, ACR vẫn
# admin disabled. Dùng lại đúng image `vsf-be` / `vsf-fe:<sha>` mà cd.yml đã push.
#
# count: tắt bằng -var 'grant_aks_acr_pull=false' để đo chứng minh ngược (pod mới
# ImagePullBackOff). Xem variables.tf.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.grant_aks_acr_pull ? 1 : 0

  scope                = data.azurerm_container_registry.base.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

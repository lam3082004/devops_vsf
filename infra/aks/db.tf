# MySQL: dùng lại SERVER của infra/app, thêm đúng hai resource con (tương đương M3).

# Database riêng — xem var.db_name. `be` tự tạo bảng lúc khởi động (SchemaInitializer).
resource "azurerm_mysql_flexible_database" "aks" {
  name                = var.db_name
  resource_group_name = local.base_rg
  server_name         = data.azurerm_mysql_flexible_server.base.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# IP outbound của cluster: AKS tạo public IP trong node RG và chỉ trả về ID của nó,
# phải tra thêm một bước để có địa chỉ.
data "azurerm_public_ip" "aks_outbound" {
  name                = basename(one(azurerm_kubernetes_cluster.aks.network_profile[0].load_balancer_profile[0].effective_outbound_ips))
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
}

# Một rule, một IP. Giá trị "known after apply" ở lần apply đầu KHÔNG cần apply nhiều
# pha như infra/app/db.tf: ở đó IP là KHOÁ của for_each (Terraform phải biết lúc plan),
# ở đây nó chỉ là một thuộc tính.
resource "azurerm_mysql_flexible_server_firewall_rule" "aks_outbound" {
  name                = "aks-outbound"
  resource_group_name = local.base_rg
  server_name         = data.azurerm_mysql_flexible_server.base.name
  start_ip_address    = data.azurerm_public_ip.aks_outbound.ip_address
  end_ip_address      = data.azurerm_public_ip.aks_outbound.ip_address
}

output "resource_group_name" {
  description = "RG của môi trường app. Mọi resource từ D8 nằm trong đây."
  value       = azurerm_resource_group.app.name
}

output "location" {
  value = azurerm_resource_group.app.location
}

output "name_suffix" {
  description = "Hậu tố dùng cho các tên phải duy nhất toàn cầu."
  value       = local.name_suffix
}

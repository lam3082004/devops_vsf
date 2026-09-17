resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.project}-${var.env}"
  location = var.location
  tags     = local.tags
}

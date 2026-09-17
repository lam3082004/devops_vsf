locals {
  tags = {
    project    = var.project
    env        = "shared"
    owner      = var.owner
    managed_by = "terraform"
    layer      = "bootstrap"
  }
}

# Hậu tố ngẫu nhiên cho các tên phải duy nhất toàn cầu (storage account).
# Nằm trong state nên ổn định giữa các lần apply.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.project}-bootstrap"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                = "st${var.project}tf${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  # Backend dùng Entra ID (use_azuread_auth), không dùng access key.
  # Tắt hẳn shared key để không ai lỡ dùng key tĩnh.
  shared_access_key_enabled = false

  blob_properties {
    # State hỏng hoặc bị ghi đè nhầm thì còn đường lấy lại.
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Người đang chạy Terraform cần quyền DATA PLANE để đọc/ghi blob state.
# Owner chỉ là control plane — đây đúng là bài học của D1.
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "me_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

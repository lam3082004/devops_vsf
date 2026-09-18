# App Service Plan + Web App + slot staging.
#
# P0v3 chứ không phải Basic: Basic không có deployment slot (M2) và autoscale (M7).
# P0v3 0.0915 USD/giờ còn rẻ hơn S1 0.095 (Retail API, SEA, 15/09).
resource "azurerm_service_plan" "app" {
  name                = "asp-${var.project}-${var.env}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  os_type             = "Linux"
  sku_name            = "P0v3"
  worker_count        = 1
  tags                = local.tags
}

locals {
  # Dùng chung cho production và staging: slot phải giống hệt site để swap
  # không mang cấu hình lạ lên production.
  app_settings = {
    # App Service chuyển traffic vào cổng này của container.
    WEBSITES_PORT = tostring(var.container_port)
    # Không mount /home dùng chung vào container: app không ghi file, tắt đi
    # để container khởi động nhanh và không phụ thuộc storage của stamp.
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  service_plan_id     = azurerm_service_plan.app.id
  tags                = local.tags

  https_only = true
  # D2 thấy Portal tắt sẵn basic auth cho FTP/SCM; Terraform phải khai rõ.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = local.app_settings

  site_config {
    always_on           = true # không cold start; slot/swap warm-up cần app luôn chạy
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Image mẫu công khai: ACR chưa có ở D8. D9 thêm ignore_changes phần image,
    # D11 đổi sang image thật pull bằng managed identity.
    # health_check_path = "/health" bật ở D17 — image mẫu không có /health.
    application_stack {
      docker_registry_url = "https://mcr.microsoft.com"
      docker_image_name   = var.placeholder_image
    }
  }

  lifecycle {
    # Từ D11, CD (D16) đổi tag image thẳng trên Azure sau mỗi lần build —
    # KHÔNG qua Terraform. Thiếu ignore_changes này, apply kế tiếp sẽ thấy
    # image trên Azure khác var.placeholder_image trong code và ĐẢO NGƯỢC về
    # placeholder, sập bản đang chạy. Từ nay: Terraform sở hữu mọi thứ của
    # Web App trừ tag image; CD sở hữu tag image (Decision, notes/d9.md).
    ignore_changes = [site_config[0].application_stack[0].docker_image_name]
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  # Hostname: app-vsf-xxxxxx-staging.azurewebsites.net — 22 ký tự, dưới giới hạn 60.
  name           = "staging"
  app_service_id = azurerm_linux_web_app.app.id
  tags           = local.tags

  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # CÙNG identity với production — thiếu khối này thì D11 slot staging pull image lỗi.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = local.app_settings

  site_config {
    always_on           = true
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Khai image cho slot một cách tường minh: D2 thấy clone slot KHÔNG copy
    # image → slot rỗng trả 503, swap lên là production chết.
    application_stack {
      docker_registry_url = "https://mcr.microsoft.com"
      docker_image_name   = var.placeholder_image
    }
  }

  lifecycle {
    # Cùng lý do với production ở trên — slot staging là nơi CD đổi tag TRƯỚC
    # khi swap (D16/D17), Terraform không được đảo nó về placeholder.
    ignore_changes = [site_config[0].application_stack[0].docker_image_name]
  }
}

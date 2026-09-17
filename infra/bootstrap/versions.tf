terraform {
  required_version = "~> 1.15"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State của bootstrap để LOCAL và không commit: nó có thể chứa access key của
  # storage account. Bootstrap chạy một lần, không nằm trong vòng destroy/apply
  # hằng ngày, nên đây là ngoại lệ có chủ đích của M8 (ghi trong Decision).
}

provider "azurerm" {
  features {}

  # Storage account này tắt shared key (shared_access_key_enabled = false).
  # Mặc định provider gọi data plane bằng access key → 403 KeyBasedAuthenticationNotPermitted.
  # Cờ dưới bắt provider dùng Entra ID cho mọi thao tác data plane của Storage.
  storage_use_azuread = true
  # subscription_id lấy từ biến môi trường ARM_SUBSCRIPTION_ID (azurerm v4 đọc sẵn).
  # Một nguồn sự thật duy nhất cho cả az CLI, Terraform và backend.
}

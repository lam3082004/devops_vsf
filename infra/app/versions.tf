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
}

provider "azurerm" {
  # subscription_id lấy từ ARM_SUBSCRIPTION_ID (azurerm v4 đọc sẵn).
  # storage_use_azuread: storage chứa state đã tắt shared key, provider phải
  # dùng Entra ID cho data plane — nếu thiếu sẽ gặp 403 KeyBasedAuthenticationNotPermitted.
  storage_use_azuread = true

  features {
    key_vault {
      # Xoá hẳn secret khi destroy, và KHÔNG tự khôi phục vault soft-deleted.
      # Thiếu hai dòng này thì destroy → apply ở GATE (D10) sẽ lỗi
      # "vault name already exists" vì tên vault vẫn bị giữ trong thời gian soft-delete.
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_key_vaults       = false
    }

    resource_group {
      # Không cho xoá RG khi bên trong còn resource lạ (do ai đó tạo tay).
      # Destroy lỗi ở đây là TÍN HIỆU TỐT: có thao tác tay ngoài Terraform.
      prevent_deletion_if_contains_resources = true
    }
  }
}

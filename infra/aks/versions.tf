terraform {
  required_version = "~> 1.15"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Cùng cấu hình với infra/app/versions.tf: subscription_id lấy từ
  # ARM_SUBSCRIPTION_ID, storage state đã tắt shared key nên phải dùng Entra ID.
  storage_use_azuread = true

  features {
    key_vault {
      # Root này KHÔNG tạo vault, chỉ ghi MỘT secret vào vault của infra/app
      # (keyvault.tf). `make aks-down` rồi `make aks-up` phải ghi lại được secret
      # cùng tên — không purge thì tên bị giữ trong thời gian soft-delete.
      purge_soft_deleted_secrets_on_destroy = true
    }

    resource_group {
      # KHÁC infra/app (true): App Insights tự sinh rule Smart Detection "Failure
      # Anomalies" ngoài Terraform (known-issues.md #30). infra/app chưa từng destroy
      # sau khi có App Insights nên chưa va; root này destroy mỗi tối, để true thì
      # `make aks-down` gãy ở bước xoá RG. RG này chỉ của riêng AKS — rác tạo tay thì
      # `make aks-check-empty` vẫn bắt được trước khi destroy.
      prevent_deletion_if_contains_resources = false
    }
  }
}

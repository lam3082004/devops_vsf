# Autoscale cho App Service Plan (D19, M7 phần autoscale).
#
# Gắn vào PLAN, không phải Web App: `be` và `fe` dùng chung plan này (app.tf,
# app-fe.tf) nên scale out là thêm máy cho CẢ HAI app — tiền tính theo instance
# của plan, `fe` lên 2 instance không tốn thêm (quyết định B, notes/d19.md).
# Metric cũng lấy từ plan (`CpuPercentage` của microsoft.web/serverfarms):
# lấy `CpuTime` của Web App là bẫy #1 của guide — rule không kích hoạt như mong đợi.
#
# Số instance ban đầu do `worker_count` của plan đặt; plan có
# ignore_changes = [worker_count] để Terraform không kéo ngược autoscale (quyết định A).
# Không có khối `notification` (quyết định C): bằng chứng lấy từ Run history +
# Activity Log, không đưa email vào code hay state.
resource "azurerm_monitor_autoscale_setting" "plan" {
  name                = "autoscale-${var.project}-${var.env}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  target_resource_id  = azurerm_service_plan.app.id
  enabled             = true
  tags                = local.tags

  profile {
    name = "cpu"

    # maximum 2 là luật project (CLAUDE.md, ngân sách Free Trial) — không nâng.
    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    # Decision (D19): ngưỡng 70/30, cửa sổ in 10 phút > out 5 phút, để chống
    # flapping. Trước khi giảm, autoscale ước tính CPU sau khi giảm (2 instance
    # 30% → 1 instance ~60%); nếu ước tính vượt ngưỡng out thì nó từ chối giảm.
    # Khoảng cách 70/30 đủ rộng để scale in vẫn xảy ra, cửa sổ in dài hơn bắt
    # tải phải thấp BỀN rồi mới bỏ máy, còn out phản ứng nhanh hơn khi tải lên.
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_namespace   = "microsoft.web/serverfarms"
        metric_resource_id = azurerm_service_plan.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_namespace   = "microsoft.web/serverfarms"
        metric_resource_id = azurerm_service_plan.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT10M"
      }
    }
  }
}

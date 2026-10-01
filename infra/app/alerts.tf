# D22: 3 alert + action group email (M11 dòng "Cảnh báo") — kế hoạch notes/d22-prep.md.
#
# Giá tra 29/09 (Retail Prices API, Central India): log alert đánh giá 5 phút/lần
# $1,50/tháng mỗi time series; metric alert $0,10/tháng mỗi time series → tổng ≈ $1,70/tháng.

locals {
  # Mô tả alert có link runbook — người trực mở thẳng từ email (quyết định G).
  runbook_url = "https://github.com/lam3082004/devops_vsf/blob/main/runbook.md"
}

# Tách action group khỏi alert rule: đổi người nhận (hay thêm Teams/SMS) chỉ sửa một chỗ,
# ba alert không đổi. Email lấy từ var.alert_email (terraform.tfvars, KHÔNG commit) — rỗng
# thì action group không có người nhận (CI plan không có tfvars nên luôn thấy rỗng, cùng
# loại "diff giả" với ip_restriction — xem variables.tf).
resource "azurerm_monitor_action_group" "oncall" {
  name                = "ag-${var.project}-oncall"
  resource_group_name = azurerm_resource_group.app.name
  short_name          = "vsfoncall" # ≤ 12 ký tự, hiện ở đầu SMS/email
  tags                = local.tags

  dynamic "email_receiver" {
    for_each = var.alert_email == "" ? [] : [var.alert_email]
    content {
      name                    = "oncall-email"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ---------- 5xx rate — log alert (người dùng chốt "rate", Q3 chưa có trả lời mentor) ----------
#
# Nguồn: AppServiceHTTPLogs (diagnostic setting D21, monitoring.tf) — không cần App Insights
# (topic.md M11). Chỉ 2 site production (`be`, `fe`); slot staging không phục vụ người dùng.
# Rate tính THEO TỪNG APP rồi lấy max → 1 time series ($1,50/tháng thay vì $3); app nào lỗi
# xem ở kết quả query của alert (runbook bước 2). "≥ 20 request" chặn báo động giả kiểu
# 1 lỗi / 2 request = 50%.
#
# Cửa sổ 10 phút (không phải 5): log về workspace trễ 2–5 phút, cửa sổ 5 phút dễ đếm thiếu
# đúng lúc sự cố bắt đầu (notes/d22-prep.md bẫy T1).
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "http_5xx_rate" {
  name                = "alert-${var.project}-5xx-rate"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  display_name        = "5xx rate > 5% (be/fe production)"
  description         = "Tỷ lệ 5xx của be hoặc fe production > 5% trong 10 phút (tối thiểu 20 request). Runbook: ${local.runbook_url}"
  severity            = 1
  enabled             = true

  scopes               = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
  # Hết điều kiện thì tự đóng → có email "Resolved" (guide D22).
  auto_mitigation_enabled = true

  criteria {
    query = <<-KQL
      AppServiceHTTPLogs
      | where _ResourceId has "/sites/" and _ResourceId !has "/slots/"
      | extend app = tostring(split(_ResourceId, "/")[8])
      | summarize total = count(), errors = countif(ScStatus >= 500) by app
      | where total >= 20
      | summarize rate_pct = max(100.0 * errors / total)
    KQL

    time_aggregation_method = "Maximum"
    metric_measure_column   = "rate_pct"
    operator                = "GreaterThan"
    threshold               = 5

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.oncall.id]
  }

  tags = local.tags
}

# ---------- CPU cao — metric alert trên PLAN ----------
#
# Scope = Plan (CpuPercentage của microsoft.web/serverfarms), KHÔNG phải Web App — bẫy của
# guide, cùng lý do autoscale.tf. 80%: cao hơn ngưỡng scale out 70% — tức autoscale đã lên
# 2 instance (max, luật project) mà vẫn quá tải. Cửa sổ 15 phút, không phải 10 như guide:
# metric alert chỉ nhận PT1M/5M/15M/30M/1H/… (provider từ chối PT10M lúc validate, 29/09);
# 5 phút thì một đợt /load ngắn cũng bắn, 15 phút mới là "quá tải bền".
resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "alert-${var.project}-cpu-high"
  resource_group_name = azurerm_resource_group.app.name
  scopes              = [azurerm_service_plan.app.id]
  description         = "CPU trung bình của App Service Plan > 80% trong 15 phút. Runbook: ${local.runbook_url}"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  auto_mitigate       = true

  criteria {
    metric_namespace = "microsoft.web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }

  tags = local.tags
}

# ---------- MySQL active connections — metric alert ----------
#
# B1ms: max_connections = 171 (đọc 29/09). Ngưỡng 128 ≈ 75% (guide: 70–80%).
# SỬA comment theo review 30/09 #6: app KHÔNG thể tự chạm ngưỡng này — `MySqlDataSourceFactory`
# đặt MaximumPoolSize = 5, nên be tối đa 5 × 2 instance × 2 slot = 20 kết nối. Alert này bắt
# kết nối từ NGUỒN KHÁC (công cụ quản trị, PoC dùng chung subscription, kết nối rò ngoài pool,
# hoặc ai đó nâng MaximumPoolSize) trước khi app nhận lỗi "Too many connections".
resource "azurerm_monitor_metric_alert" "mysql_connections" {
  name                = "alert-${var.project}-mysql-connections"
  resource_group_name = azurerm_resource_group.app.name
  scopes              = [azurerm_mysql_flexible_server.db.id]
  description         = "MySQL active connections > 128 (75% của max_connections 171) trong 5 phút. Runbook: ${local.runbook_url}"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true

  criteria {
    metric_namespace = "microsoft.dbformysql/flexibleservers"
    metric_name      = "active_connections"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 128
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }

  tags = local.tags
}

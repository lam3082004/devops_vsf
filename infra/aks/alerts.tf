# 3 alert cho bản chạy trên AKS (tương đương M11 dòng "Cảnh báo").
#
# Action group KHÔNG tạo mới: tham chiếu `ag-vsf-oncall` của infra/app (email đã xác
# minh OTP, known-issues.md #28) — chỉ đọc ID, không sửa gì ở đó.
# Alert thứ ba của đề bài (MySQL connections) đã có ở infra/app và phủ luôn AKS vì dùng
# chung server; ở đây thay bằng alert "pod không khởi động được", thứ App Service không có.

locals {
  aks_runbook_url = "https://github.com/lam3082004/devops_vsf/blob/main/docs/aks.md#runbook"
}

data "azurerm_monitor_action_group" "oncall" {
  name                = "ag-${var.project}-oncall"
  resource_group_name = local.base_rg
}

# ---------- 5xx rate — log alert ----------
#
# Cùng ngưỡng và cửa sổ với alert-vsf-5xx-rate (> 5% / 10 phút, ≥ 20 request, Q3 mentor
# trả lời 05/10). Khác nguồn: App Service có AppServiceHTTPLogs của nền tảng, AKS thì
# không — dùng AppRequests do OpenTelemetry của chính app gửi về App Insights.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "http_5xx_rate" {
  name                = "alert-${var.project}-aks-5xx-rate"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  display_name        = "AKS: 5xx rate > 5% (be/fe)"
  description         = "Tỷ lệ 5xx của be hoặc fe trên AKS > 5% trong 10 phút (tối thiểu 20 request). Runbook: ${local.aks_runbook_url}"
  severity            = 1
  enabled             = true

  scopes                  = [azurerm_log_analytics_workspace.aks.id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  auto_mitigation_enabled = true

  criteria {
    query = <<-KQL
      AppRequests
      | summarize total = count(), errors = countif(toint(ResultCode) >= 500) by AppRoleName
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
    action_groups = [data.azurerm_monitor_action_group.oncall.id]
  }

  tags = local.tags
}

# ---------- CPU node cao — metric alert trên CLUSTER ----------
#
# Metric nền tảng của AKS (miễn phí, không qua workspace). 80% / 15 phút như
# alert-vsf-cpu-high: cao hơn ngưỡng HPA 70%, tức đã scale hết mức mà vẫn quá tải.
resource "azurerm_monitor_metric_alert" "node_cpu_high" {
  name                = "alert-${var.project}-aks-node-cpu-high"
  resource_group_name = azurerm_resource_group.aks.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "CPU trung bình của node AKS > 80% trong 15 phút. Runbook: ${local.aks_runbook_url}"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  auto_mitigate       = true

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.oncall.id
  }

  tags = local.tags
}

# ---------- Pod không khởi động được — log alert ----------
#
# Bắt đúng các kiểu gãy mà bài chứng minh ngược tạo ra: mất AcrPull → ImagePullBackOff,
# cấu hình/secret sai → CreateContainerConfigError, app thoát lúc khởi động → CrashLoopBackOff.
# Cửa sổ 10 phút: một lần rollout bình thường không để pod ở các trạng thái này.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_not_starting" {
  name                = "alert-${var.project}-aks-pod-not-starting"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  display_name        = "AKS: pod không khởi động được (${local.k8s_namespace})"
  description         = "Có pod trong namespace ${local.k8s_namespace} kẹt ở ImagePullBackOff / CrashLoopBackOff / CreateContainerConfigError. Runbook: ${local.aks_runbook_url}"
  severity            = 2
  enabled             = true

  scopes                  = [azurerm_log_analytics_workspace.aks.id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  auto_mitigation_enabled = true

  criteria {
    query = <<-KQL
      KubePodInventory
      | where Namespace == "${local.k8s_namespace}"
      | where ContainerStatusReason in ("ImagePullBackOff", "ErrImagePull", "CrashLoopBackOff", "CreateContainerConfigError")
      | summarize bad_pods = dcount(Name)
    KQL

    time_aggregation_method = "Maximum"
    metric_measure_column   = "bad_pods"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [data.azurerm_monitor_action_group.oncall.id]
  }

  tags = local.tags
}

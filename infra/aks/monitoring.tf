# Monitoring của AKS (tương đương M11) — TÁCH HẲN khỏi workspace của infra/app.
#
# Vì sao không dùng chung `log-vsf-<suffix>`: workspace đó có daily cap 0,2 GB dùng cho
# telemetry của App Service. Log container đổ chung vào thì có thể chạm cap và workspace
# NGỪNG THU tới hết ngày — tức cắt luôn dashboard/alert của môi trường demo. Tách ra thì
# AKS có ồn mấy cũng không ảnh hưởng, và `/boom` trên AKS không bắn alert của App Service.
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "log-${var.project}-aks-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "PerGB2018"

  # Cùng con số với quyết định B của D20 (người dùng duyệt 28/09): 30 ngày, cap
  # 0,2 GB/ngày. Chạm cap = mất telemetry tới hết ngày, không mất tiền.
  retention_in_days = 30
  daily_quota_gb    = 0.2

  tags = local.tags
}

# Trace + request của `be`/`fe` chạy trên AKS. App không đổi một dòng code: vẫn đọc
# APPLICATIONINSIGHTS_CONNECTION_STRING (Telemetry.cs, instrumentation.node.ts), chỉ
# khác là giá trị trỏ về đây.
resource "azurerm_application_insights" "aks" {
  name                = "appi-${var.project}-aks-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  workspace_id        = azurerm_log_analytics_workspace.aks.id
  application_type    = "web"

  tags = local.tags
}

# Connection string vào Key Vault của infra/app, giữ đúng quy tắc quyết định C của D20:
# cấu hình của app không chứa giá trị lấy từ resource, chỉ tham chiếu. Người ghi là
# người vận hành — đã có Key Vault Secrets Officer từ infra/app/keyvault.tf.
resource "azurerm_key_vault_secret" "appinsights_connection_string" {
  name         = local.appinsights_secret_name
  value        = azurerm_application_insights.aks.connection_string
  key_vault_id = data.azurerm_key_vault.base.id
}

# ---------- Container Insights: thu gì, từ đâu ----------
#
# Bật add-on `oms_agent` (cluster.tf) bằng Terraform KHÔNG tự sinh data collection rule
# như `az aks enable-addons` — thiếu hai resource dưới thì agent chạy mà không gửi gì.
#
# Chỉ thu namespace của app: log của kube-system rất ồn và sẽ ăn hết cap 0,2 GB/ngày.
# Không thu Prometheus metrics (managed Prometheus + Grafana là dịch vụ tính tiền riêng
# và thêm pod trên node 2 vCPU đã chật) — CPU/memory lấy từ bảng Perf.
locals {
  container_insights_streams = [
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-Perf",
  ]
}

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "dcr-${local.cluster_name}-ci"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  description         = "Container Insights của ${local.cluster_name}: chỉ namespace ${local.k8s_namespace}"

  destinations {
    log_analytics {
      name                  = "aks-workspace"
      workspace_resource_id = azurerm_log_analytics_workspace.aks.id
    }
  }

  data_flow {
    streams      = local.container_insights_streams
    destinations = ["aks-workspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = local.container_insights_streams
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Include"
          namespaces             = [local.k8s_namespace]
          enableContainerLogV2   = true
        }
      })
    }
  }

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  # Tên cố định mà agent tìm — đặt tên khác thì agent không nhận rule.
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
  description             = "Gắn rule Container Insights vào ${local.cluster_name}"
}

# ---------- Workbook ----------
#
# Workbook RIÊNG, không sửa Workbook M11 của infra/app. Cùng cách dựng: template JSON +
# templatefile(), name là uuidv5 từ chuỗi cố định (uuid() thì mỗi plan đòi thay).
resource "azurerm_application_insights_workbook" "aks" {
  name                = uuidv5("url", "https://github.com/lam3082004/devops_vsf/workbooks/aks/${local.name_suffix}")
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  display_name        = "OpsBoard — AKS advanced (${local.name_suffix})"
  source_id           = "azure monitor"
  category            = "workbook"

  data_json = templatefile("${path.module}/workbooks/aks.workbook.json.tftpl", {
    env            = local.name_suffix
    cluster_name   = local.cluster_name
    namespace      = local.k8s_namespace
    workspace_id   = azurerm_log_analytics_workspace.aks.id
    workspace_name = azurerm_log_analytics_workspace.aks.name
  })

  tags = local.tags
}

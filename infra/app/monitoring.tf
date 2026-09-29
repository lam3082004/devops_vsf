# D20: Log Analytics workspace + Application Insights workspace-based cho tracing của `be`.
#
# Workspace KHÔNG theo cờ enable_app_insights: D21 (diagnostic settings, KQL, dashboard
# M11) dùng lại chính workspace này dù App Insights có bật hay không. topic.md M11 cấm
# dựng dashboard trên App Insights — App Insights ở đây chỉ là nơi đọc trace + exception
# (/boom), notes/d20-prep.md bẫy T9.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  sku                 = "PerGB2018"

  # Quyết định B (D20, người dùng duyệt 2026-09-28): 30 ngày đủ tới demo D25; cap 0,2 GB/ngày
  # ≈ 6 GB/tháng, sát mức 5 GB/tháng miễn phí. Chạm cap thì workspace NGỪNG THU tới hết
  # ngày (mất telemetry, không mất tiền) — muốn nới phải hỏi lại, đây là giới hạn chi phí.
  retention_in_days = 30
  daily_quota_gb    = 0.2

  tags = local.tags
}

# Q1 (known-issues.md #5) chưa có trả lời của mentor → dựng TẠM theo mặc định của plan.
# Mentor nói "không" thì đặt enable_app_insights = false: gỡ App Insights, secret và app
# setting; app tự tắt telemetry khi không có connection string (app/be/Infrastructure/Telemetry.cs).
resource "azurerm_application_insights" "be" {
  count = var.enable_app_insights ? 1 : 0

  name                = "appi-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.tags
}

# Connection string vào Key Vault, app setting chỉ là tham chiếu — quyết định C (D20).
# Microsoft coi connection string "không phải secret" (nó chỉ cho GỬI telemetry vào), nhưng
# giữ một quy tắc duy nhất cho app settings: không chứa giá trị nào lấy từ resource, chỉ
# tham chiếu (M4). Không tốn thêm quyền: identity của app đã có Secrets User ở scope vault.
locals {
  # Dùng ở đây và trong app setting (app.tf) — xem lý do dựng URI tay ở đó.
  appinsights_secret_name = "appinsights-connection-string"
}

resource "azurerm_key_vault_secret" "appinsights_connection_string" {
  count = var.enable_app_insights ? 1 : 0

  name         = local.appinsights_secret_name
  value        = azurerm_application_insights.be[0].connection_string
  key_vault_id = azurerm_key_vault.kv.id

  # Cùng lý do với mysql_admin_password (keyvault.tf): ghi secret cần role đã lan truyền.
  depends_on = [azurerm_role_assignment.kv_secrets_officer_operator]
}

# ---------- D21: diagnostic settings → workspace ở trên ----------
#
# Gắn vào TỪNG resource — slot staging là resource riêng (…/sites/<app>/slots/staging),
# quên nó thì staging câm (notes/d21-prep.md bẫy T1). Setting gắn vào slot, không đi
# theo code khi swap.
#
# Category — quyết định A (người dùng chốt 2026-09-29): HTTP (Q1–Q3), Console = log JSON
# của app trên stdout (Q4–Q5), Platform = container start/stop (Q6), IPSecAudit = request
# bị 403 bởi ip_restriction, tức M6 dạng log (Q7). Bỏ AppLogs (app không ghi qua logging
# của App Service) và các loại audit file/antivirus/auth (không dùng, tốn ingest).
#
# Không đẩy AllMetrics — quyết định B: Workbook đọc metric thẳng từ Azure Monitor (miễn
# phí, giữ 93 ngày), đẩy vào workspace chỉ nhân đôi dữ liệu và ăn cap 0,2 GB/ngày.
#
# Tên "diag-vsf" khác "obs-poc" (setting của PoC khác đã có trên 2 site chính, ngoài repo
# này) — không import, không đụng tới (bẫy T4). Mỗi resource cho tối đa 5 setting.
locals {
  diag_web_targets = {
    "be"         = azurerm_linux_web_app.app.id
    "be-staging" = azurerm_linux_web_app_slot.staging.id
    "fe"         = azurerm_linux_web_app.fe.id
    "fe-staging" = azurerm_linux_web_app_slot.fe_staging.id
  }

  diag_web_log_categories = [
    "AppServiceHTTPLogs",
    "AppServiceConsoleLogs",
    "AppServicePlatformLogs",
    "AppServiceIPSecAuditLogs",
  ]
}

resource "azurerm_monitor_diagnostic_setting" "web" {
  for_each = local.diag_web_targets

  name                       = "diag-${var.project}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  dynamic "enabled_log" {
    for_each = toset(local.diag_web_log_categories)
    content {
      category = enabled_log.value
    }
  }
}

# MySQL slow log — quyết định C (b), người dùng chốt 2026-09-29 ("làm đầy đủ").
# Server parameter dynamic (không restart). long_query_time = 1 giây: ngưỡng thật cho một
# app CRUD nhỏ (mặc định 10 giây thì gần như không bao giờ có dòng nào).
#
# log_queries_not_using_indexes TẮT tường minh. PR #64 bật nó (throttle 10 dòng/phút) để thấy
# query quét toàn bảng; đo 29/09 sau apply: 24/26 dòng là query giám sát nội bộ của Azure
# (azure_superuser, INFORMATION_SCHEMA, ~30 giây/lần) — nhiễu ~14 000 dòng/ngày, lại tiêu
# hết hạn mức throttle nên có thể đè mất đúng dòng của app. Bằng chứng nó đã bắt được query
# của app (`/items` quét toàn bảng tickets): evidence/raw/d21-mysql-slowlog-20260929.tsv.
locals {
  mysql_slow_log_parameters = {
    slow_query_log                = "ON"
    long_query_time               = "1"
    log_queries_not_using_indexes = "OFF"
  }
}

resource "azurerm_mysql_flexible_server_configuration" "slow_log" {
  for_each = local.mysql_slow_log_parameters

  name                = each.key
  resource_group_name = azurerm_resource_group.app.name
  server_name         = azurerm_mysql_flexible_server.db.name
  value               = each.value
}

# Chỉ MySqlSlowLogs: MySqlAuditLogs cần bật audit_log_enabled và ghi mọi kết nối/query →
# ingest lớn, M11 không đòi. Metric MySQL không đẩy vào workspace — cùng lý do quyết định B.
resource "azurerm_monitor_diagnostic_setting" "mysql" {
  name                       = "diag-${var.project}"
  target_resource_id         = azurerm_mysql_flexible_server.db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "MySqlSlowLogs"
  }
}

# ---------- D21: Workbook M11 (dashboard) ----------
#
# Dashboard KHÔNG dùng App Insights cho metric/log (topic.md M11, bẫy T7): `source_id =
# "azure monitor"` — Workbook đứng riêng dưới Azure Monitor, metric đọc thẳng từ resource,
# log từ workspace ở trên. App Insights chỉ xuất hiện ở ô "Trace" (bảng AppRequests trong
# cùng workspace).
#
# JSON trong file template (dựng theo schema Notebook/1.0 của Workbook), mọi resource ID
# truyền vào qua templatefile() — không ID/subscription cứng trong repo, và Workbook dựng
# lại đúng sau `make up` với suffix mới (bẫy T6).
#
# name phải là UUID: uuidv5 từ chuỗi cố định → ổn định giữa các lần plan (uuid() thì mỗi
# plan đòi thay Workbook — bẫy T5). Suffix nằm trong chuỗi nên môi trường mới có ID mới.
resource "azurerm_application_insights_workbook" "m11" {
  name                = uuidv5("url", "https://github.com/lam3082004/devops_vsf/workbooks/m11/${local.name_suffix}")
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  display_name        = "OpsBoard — M11 (${local.name_suffix})"
  source_id           = "azure monitor"
  category            = "workbook"

  data_json = templatefile("${path.module}/workbooks/m11.workbook.json.tftpl", {
    env                 = local.name_suffix
    subscription_id     = data.azurerm_client_config.current.subscription_id
    resource_group_name = azurerm_resource_group.app.name
    workspace_id        = azurerm_log_analytics_workspace.main.id
    workspace_name      = azurerm_log_analytics_workspace.main.name
    be_id               = azurerm_linux_web_app.app.id
    fe_id               = azurerm_linux_web_app.fe.id
    plan_id             = azurerm_service_plan.app.id
    plan_name           = azurerm_service_plan.app.name
    mysql_id            = azurerm_mysql_flexible_server.db.id
    mysql_name          = azurerm_mysql_flexible_server.db.name
  })

  tags = local.tags
}

# D23 — quyền Azure của "agent đọc sự cố" (id-agent-triage, infra/bootstrap/agent.tf).
# Bảng thiết kế quyền + chứng minh ngược: evidence/agent.md.
#
# Agent chỉ ĐỌC: log/trace trong Log Analytics, alert đang bắn, metric. Không đọc
# cấu hình Web App (app settings, access restriction chứa IP cá nhân), không đọc
# secret, không ghi gì. Quyền nằm ở state này (không phải bootstrap) để sinh/mất
# cùng môi trường (quyết định C, notes/d23-prep.md).
data "azurerm_user_assigned_identity" "agent_triage" {
  name                = "id-agent-triage"
  resource_group_name = "rg-vsf-bootstrap"
}

# Chạy KQL trên mọi bảng M11 (AppServiceHTTPLogs, AppServiceConsoleLogs,
# AppRequests/AppExceptions của App Insights workspace-based...). Role built-in
# đã loại `workspaces/sharedKeys/read`, nên không lấy được key để ghi log giả.
# Scope đúng workspace: `*/read` của role này chỉ phủ chính workspace, không lan
# ra Web App hay Key Vault cùng RG.
resource "azurerm_role_assignment" "agent_triage_log_reader" {
  scope                = azurerm_log_analytics_workspace.main.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = data.azurerm_user_assigned_identity.agent_triage.principal_id
}

# Alert đang Fired và metric (Plan/Web App/MySQL). KHÔNG dùng Monitoring Reader:
# role đó có `*/read` → đọc được ip_restriction (IP cá nhân trong whitelist M6) và
# mọi cấu hình khác của RG. Custom role chỉ đúng 3 action, mẫu ci-permissions.tf.
resource "azurerm_role_definition" "agent_alert_reader" {
  name  = "vsf-agent-alert-reader"
  scope = azurerm_resource_group.app.id

  permissions {
    actions = [
      "Microsoft.AlertsManagement/alerts/read",
      "Microsoft.Insights/metrics/read",
      "Microsoft.Insights/metricDefinitions/read",
    ]
    not_actions = []
  }

  assignable_scopes = [azurerm_resource_group.app.id]
}

resource "azurerm_role_assignment" "agent_triage_alert_reader" {
  scope              = azurerm_resource_group.app.id
  role_definition_id = azurerm_role_definition.agent_alert_reader.role_definition_resource_id
  principal_id       = data.azurerm_user_assigned_identity.agent_triage.principal_id
}

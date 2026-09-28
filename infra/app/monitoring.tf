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

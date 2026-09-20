# Quyền bổ sung riêng cho id-gh-plan (CI) — phát hiện khi PR #11 lần đầu chạy
# `terraform plan` full trên state đã có Web App thật (trước đó CI luôn ở
# nhánh "pha 1"/state rỗng nên chưa từng full-refresh resource này).
#
# `azurerm_linux_web_app`/slot khi refresh luôn gọi API đọc auth settings.
# Role "Reader" built-in chỉ cấp hành động dạng .../read, KHÔNG cấp
# Microsoft.Web/sites/config/list/action (dạng "list" — cùng nhóm với
# listKeys/listSecrets, luôn cần quyền tường minh riêng ngoài Reader).
# Không dùng "Website Contributor" (built-in, có quyền ghi rộng) vì id-gh-plan
# chỉ được PLAN, không được APPLY (quyết định D7) — custom role dưới đây chỉ
# đúng 2 action list cần thiết, không hơn.
resource "azurerm_role_definition" "gh_plan_web_config_reader" {
  name  = "vsf-gh-plan-web-config-reader"
  scope = azurerm_resource_group.app.id

  permissions {
    actions = [
      "Microsoft.Web/sites/config/list/action",
      "Microsoft.Web/sites/slots/config/list/action",
    ]
    not_actions = []
  }

  assignable_scopes = [azurerm_resource_group.app.id]
}

resource "azurerm_role_assignment" "gh_plan_web_config_reader" {
  scope              = azurerm_resource_group.app.id
  role_definition_id = azurerm_role_definition.gh_plan_web_config_reader.role_definition_resource_id
  principal_id       = data.azurerm_user_assigned_identity.gh_plan.principal_id
}

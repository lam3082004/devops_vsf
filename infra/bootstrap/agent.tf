# D23 — danh tính cho "agent đọc sự cố" (.github/workflows/agent-triage.yml).
#
# Danh tính RIÊNG, không dùng chung id-gh-plan/id-gh-deploy: mỗi agent một danh
# tính để quyền, nhật ký đăng nhập và việc thu hồi tách bạch (notes/d23-prep.md).
#
# Khai ở BOOTSTRAP (quyết định C, D23): client id cố định qua các vòng
# `make down`/`make up` → biến GitHub AZURE_AGENT_CLIENT_ID chỉ set một lần.
# Quyền Azure của nó (role assignment) khai ở infra/app/agent-permissions.tf:
# môi trường tắt thì quyền mất theo, dựng lại thì có lại.

resource "azurerm_user_assigned_identity" "agent_triage" {
  name                = "id-agent-triage"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "agent-triage" })
}

# Chỉ tin token của job khai `environment: agent-triage`. Environment đó có
# deployment branch policy chỉ nhận `main` (cấu hình ở GitHub, README mục
# Bootstrap), nên chạy workflow từ nhánh khác bị GitHub chặn trước khi xin token.
# Không có credential dạng `ref:refs/heads/...` hay `pull_request`: PR không bao
# giờ được đăng nhập bằng danh tính này.
#
# Cả dạng tên lẫn dạng immutable, cùng lý do với cicd.tf (repo bật immutable
# subject, ai-failure-log.md #4).
resource "azurerm_federated_identity_credential" "agent_triage_env" {
  name                = "github-env-agent-triage"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.agent_triage.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:environment:agent-triage"
}

resource "azurerm_federated_identity_credential" "agent_triage_env_immutable" {
  name                = "github-env-agent-triage-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.agent_triage.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:environment:agent-triage"
}

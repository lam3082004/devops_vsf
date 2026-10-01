# Danh tính cho GitHub Actions.
#
# Vì sao là user-assigned managed identity chứ không phải app registration:
# tenant VINACADEMY LLC đặt allowedToCreateApps = false (kiểm chứng ngày 15/09
# qua Graph API), user thường KHÔNG tạo được app registration. Managed identity
# chỉ cần quyền RBAC trên subscription — thứ mình đang có với vai trò Owner.
#
# Hai danh tính tách riêng để giữ least privilege: CI chạy trên PR chỉ cần đọc,
# CD chạy trên main mới được ghi (role của deploy thêm ở D16).

resource "azurerm_user_assigned_identity" "gh_plan" {
  name                = "id-gh-plan"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "ci-plan" })
}

resource "azurerm_user_assigned_identity" "gh_deploy" {
  name                = "id-gh-deploy"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
  tags                = merge(local.tags, { purpose = "cd-deploy" })
}

# ---------- Federated credentials ----------
# GitHub cấp cho mỗi lần chạy workflow một token có chữ ký; Entra tin token đó
# nếu "subject" khớp đúng chuỗi khai báo dưới. Không có client secret nào.
#
# subject là thứ bảo đảm "chỉ main mới deploy được" NGAY Ở TẦNG DANH TÍNH:
# token sinh từ pull_request mang subject khác, Entra sẽ từ chối.

locals {
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]

  # Repo này bật immutable subject (kiểm chứng: gh api repos/<o>/<r>/actions/oidc/customization/sub
  # → use_immutable_subject: true). GitHub gửi subject kèm ID số, ví dụ:
  #   repo:lam3082004@67915284/devops_vsf@1371039109:pull_request
  # Giữ CẢ HAI dạng credential: dạng tên (phòng khi setting đổi) và dạng ID.
  github_repo_name      = var.github_repo
  github_repo_immutable = "${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}"
}

resource "azurerm_federated_identity_credential" "gh_plan_pr" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_plan.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:pull_request"
}

resource "azurerm_federated_identity_credential" "gh_deploy_main" {
  name                = "github-main"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:ref:refs/heads/main"
}

# Cùng ý nghĩa nhưng theo dạng immutable (kèm ID số) — đây mới là dạng GitHub
# đang thực sự gửi lên.
resource "azurerm_federated_identity_credential" "gh_plan_pr_immutable" {
  name                = "github-pull-request-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_plan.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:pull_request"
}

resource "azurerm_federated_identity_credential" "gh_deploy_main_immutable" {
  name                = "github-main-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:ref:refs/heads/main"
}

# ---------- Federated credentials cho GitHub environment (D16) ----------
# Khi một job khai `environment: <tên>`, GitHub đổi subject của token OIDC từ
# dạng `repo:O/R:ref:refs/heads/main` sang `repo:O/R:environment:<tên>` — nó
# KHÔNG còn mang thông tin nhánh nữa. Job `build-deploy-staging`
# (environment: staging-deploy) và `swap` (environment: production) của
# cd.yml sẽ đăng nhập Azure thất bại nếu thiếu đúng 4 credential dưới đây
# (notes/d16-prep.md không nêu bẫy này — phát hiện lúc làm D16 Việc 5).
#
# Cả DẠNG TÊN lẫn DẠNG IMMUTABLE, cùng lý do với github-main/-immutable ở
# trên: repo bật immutable subject (local.github_repo_immutable,
# ai-failure-log.md #4) nên GitHub thực sự gửi subject kèm ID số, nhưng giữ cả
# dạng tên phòng khi setting đổi.
#
# CỐ Ý GIỮ credential `github-main`/`github-main-immutable` (subject
# ref:refs/heads/main) dù job có environment không còn dùng dạng subject đó:
# job `preflight` (cd.yml) KHÔNG khai environment — đó chính là lớp bảo vệ
# thứ 3 của "chỉ main mới deploy được" (bước 4, notes/d16-prep.md). Chạy
# workflow tay từ nhánh khác thì `preflight` chạy với subject
# `ref:refs/heads/<nhánh>`, không khớp bất kỳ credential nào ở file này —
# Entra từ chối cấp token, sập trước khi kịp tới job có environment.
resource "azurerm_federated_identity_credential" "gh_deploy_staging_deploy_env" {
  name                = "github-env-staging-deploy"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:environment:staging-deploy"
}

resource "azurerm_federated_identity_credential" "gh_deploy_staging_deploy_env_immutable" {
  name                = "github-env-staging-deploy-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:environment:staging-deploy"
}

resource "azurerm_federated_identity_credential" "gh_deploy_production_env" {
  name                = "github-env-production"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:environment:production"
}

resource "azurerm_federated_identity_credential" "gh_deploy_production_env_immutable" {
  name                = "github-env-production-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_deploy.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:environment:production"
}

# Drift detection theo lịch (.github/workflows/drift.yml, PR DevSecOps 01/10): job khai
# `environment: drift-check` (chỉ nhận `main`) và đăng nhập bằng id-gh-plan — CHỈ ĐỌC,
# đúng quyền cần cho `terraform plan -refresh-only`. Không dùng subject `ref:refs/heads/main`
# cho id-gh-plan: như vậy mọi workflow trên main đều lấy được danh tính đọc secret DB.
resource "azurerm_federated_identity_credential" "gh_plan_drift_env" {
  name                = "github-env-drift-check"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_plan.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${var.github_repo}:environment:drift-check"
}

resource "azurerm_federated_identity_credential" "gh_plan_drift_env_immutable" {
  name                = "github-env-drift-check-immutable"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.gh_plan.id
  audience            = local.github_audience
  issuer              = local.github_issuer
  subject             = "repo:${local.github_repo_immutable}:environment:drift-check"
}

# ---------- Quyền tối thiểu ----------

# CI chỉ cần ĐỌC trạng thái hạ tầng để chạy plan.
resource "azurerm_role_assignment" "gh_plan_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.gh_plan.principal_id
}

# Nhưng vẫn cần quyền GHI blob: `terraform plan` cũng lấy lease trên state,
# và lease là thao tác ghi. Chỉ cấp ở đúng storage account chứa state.
resource "azurerm_role_assignment" "gh_plan_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_plan.principal_id
}

# CD cũng cần đọc/ghi state để apply. Các quyền tạo resource (AcrPush,
# Website Contributor, ...) sẽ thêm ở D16 khi dựng pipeline CD.
resource "azurerm_role_assignment" "gh_deploy_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_deploy.principal_id
}

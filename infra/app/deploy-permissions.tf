# Quyền cho id-gh-deploy (CD, D16) — infra/bootstrap/cicd.tf:99 ghi sẵn phần
# này để dành D16. Khai ở ĐÂY (infra/app), không phải infra/bootstrap: ACR và
# Web App sống ở state này, và quyết định D7 giữ hai state độc lập.
#
# Tra identity bằng data source theo tên, đúng mẫu data.azurerm_user_assigned_identity.gh_plan
# (keyvault.tf:7) — KHÔNG terraform_remote_state (D7).
data "azurerm_user_assigned_identity" "gh_deploy" {
  name                = "id-gh-deploy"
  resource_group_name = "rg-vsf-bootstrap"
}

# Push image be/fe lên ACR sau khi build (D16 cd.yml). Scope đúng ACR, không
# rộng hơn — CD không cần quyền gì khác trên registry.
resource "azurerm_role_assignment" "gh_deploy_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_user_assigned_identity.gh_deploy.principal_id
}

# Đổi tag image trên slot staging, swap slot, và (D17) sửa access restriction
# tạm để chạy smoke test trước swap.
#
# Scope là RESOURCE GROUP (azurerm_resource_group.app.id), không phải từng Web
# App: bài này có HAI Web App (`be`, `fe`) × 2 slot mỗi cái = 4 bề mặt, gán
# lẻ ở scope app là 4 assignment và dễ sót slot — đúng bẫy #5 của
# docs/guides/d16-cd.md ("quyền gán ở scope app nhưng không bao gồm slot").
# Gán một lần ở RG bao trùm cả 4, không sót cái nào kể cả khi D17 thêm bề mặt
# mới.
resource "azurerm_role_assignment" "gh_deploy_website_contributor" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Website Contributor"
  principal_id         = data.azurerm_user_assigned_identity.gh_deploy.principal_id
}

# BẮT BUỘC, DỄ SÓT: AcrPush chỉ cấp hai action data-plane
# (Microsoft.ContainerRegistry/registries/pull/read và .../push/write —
# kiểm chứng bằng `az role definition list --name AcrPush --query
# "[].permissions"`, 23/09), KHÔNG cấp Microsoft.ContainerRegistry/registries/read
# (control-plane). `az acr login`/`az acr show` (CD dùng để tra login server
# trước khi docker push) gọi action control-plane này → 403 nếu thiếu.
# `Website Contributor` ở trên cũng không cấp quyền đọc ACR — hai role không
# chồng lấn nhau ở đây. Reader ở scope resource group là đủ vì ACR nằm trong
# RG đó.
resource "azurerm_role_assignment" "gh_deploy_reader" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_user_assigned_identity.gh_deploy.principal_id
}

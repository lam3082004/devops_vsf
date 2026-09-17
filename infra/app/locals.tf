locals {
  # Hậu tố cho các tên phải duy nhất toàn cầu (Web App, ACR, Key Vault, MySQL).
  # Nằm trong state nên ổn định giữa các lần apply; đổi khi destroy rồi apply lại.
  name_suffix = random_string.suffix.result

  # Tag gắn cho mọi resource: lọc chi phí theo project trong Cost Analysis (M7)
  # và biết resource nào do Terraform quản lý.
  tags = {
    project    = var.project
    env        = var.env
    owner      = var.owner
    managed_by = "terraform"
    layer      = "app"
  }
}

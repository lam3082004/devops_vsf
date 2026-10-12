locals {
  # RG của infra/app — nơi có ACR, Key Vault, MySQL mà root này DÙNG LẠI (chỉ đọc
  # + thêm resource con, không sửa cái có sẵn).
  base_rg = "rg-${var.project}-${var.env}"

  # Hậu tố của môi trường nền, suy từ tên ACR đang có thay vì nhận qua biến: `make`
  # và CI không phải truyền gì, và không thể lệch với thực tế. try() để khi môi trường
  # nền chưa dựng thì lỗi hiện ra là precondition ở main.tf (đọc được), không phải
  # "argument must not be null".
  name_suffix = try(
    trimprefix(one(data.azurerm_resources.base_acr.resources[*].name), "acr${var.project}"),
    "chua-co-moi-truong-nen",
  )

  # Tên cố định (không hậu tố): cluster và RG chỉ cần duy nhất trong subscription.
  cluster_name = "aks-${var.project}-${var.env}"

  # Namespace + service account của app trên cluster. Khai Ở ĐÂY vì federated
  # credential (identity.tf) phải khớp từng ký tự với manifest (k8s/base/).
  k8s_namespace = "opsboard"

  # Tên secret trong Key Vault. Secret MySQL do infra/app tạo (keyvault.tf ở đó);
  # secret App Insights của AKS do root này tạo (monitoring.tf).
  mysql_secret_name       = "mysql-admin-password"
  appinsights_secret_name = "aks-appinsights-connection-string"

  # Danh sách CIDR đã sắp xếp: thứ tự ổn định giữa các lần plan.
  allowed_cidrs = sort(values(var.allowed_ips))

  tags = {
    project    = var.project
    env        = var.env
    owner      = var.owner
    managed_by = "terraform"
    layer      = "aks"
  }
}

# MySQL Flexible Server + database + firewall theo outbound IPs của App Service.

# Mật khẩu admin sinh ngẫu nhiên. `sensitive` chỉ giấu khỏi output của plan/apply,
# KHÔNG mã hoá trong state: giá trị nằm rõ trong app.tfstate → storage state
# phải khoá quyền (đã làm ở bootstrap: tắt shared key, chỉ RBAC).
resource "random_password" "mysql_admin" {
  length      = 32
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Bỏ @ : / ? # % & và dấu nháy — các ký tự này phá connection string/URL
  # (vd mysql://user:pa@ss@host bị cắt sai chỗ).
  override_special = "-_.~!*"
}

resource "azurerm_mysql_flexible_server" "db" {
  name                = "mysql-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = local.tags

  sku_name = "B_Standard_B1ms"
  # 8.4 thay vì 8.0: trùng bản Portal mặc định ở D2 (8.4.9-azure) và bản chạy
  # local trong docker-compose → test local và Azure cùng một engine.
  version = "8.4"

  administrator_login    = "vsfadmin"
  administrator_password = random_password.mysql_admin.result

  backup_retention_days        = 1 # tối thiểu — tiết kiệm (M7)
  geo_redundant_backup_enabled = false
  # Không khai high_availability → HA tắt.

  storage {
    size_gb           = 20
    auto_grow_enabled = false # không để dung lượng (và tiền) tự tăng
  }

  lifecycle {
    # Không chỉ định zone: Azure tự chọn lúc tạo. Nếu không bỏ qua, plan sau
    # sẽ luôn muốn đổi zone từ giá trị Azure chọn về null.
    ignore_changes = [zone]
  }
}

resource "azurerm_mysql_flexible_database" "app" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.app.name
  server_name         = azurerm_mysql_flexible_server.db.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# ---------- Firewall: một rule cho mỗi possible outbound IP ----------
#
# Dùng "possible" chứ không phải "current": current (7 IP ở D2) chỉ là tập con
# đang dùng; khi scale/đổi worker, app có thể đi ra bằng bất kỳ IP nào trong
# possible (19–20 IP) → thiếu rule là mất kết nối DB ngẫu nhiên.
#
# Vì sao cần APPLY 2 PHA (Makefile `up`): lần apply đầu Web App chưa tồn tại,
# danh sách IP là "known after apply" → Terraform không tính được tập khoá của
# for_each lúc plan và từ chối (Invalid for_each argument). Pha 1 tạo Web App
# trước, pha 2 IP đã nằm trong state nên for_each biết đủ khoá.
# Chi tiết và 2 cách còn lại: Decision trong notes/d8.md.
#
# for_each trên TẬP IP (khoá = chính IP) thay vì count: Azure đổi thứ tự hoặc
# thêm/bớt một IP thì chỉ rule của IP đó bị tạo/xoá; với count, mọi rule sau
# vị trí thay đổi sẽ bị đánh số lại → xoá và tạo lại hàng loạt.
resource "azurerm_mysql_flexible_server_firewall_rule" "app_outbound" {
  for_each = toset(azurerm_linux_web_app.app.possible_outbound_ip_address_list)

  name                = "app-outbound-${replace(each.value, ".", "-")}"
  resource_group_name = azurerm_resource_group.app.name
  server_name         = azurerm_mysql_flexible_server.db.name
  start_ip_address    = each.value
  end_ip_address      = each.value
}

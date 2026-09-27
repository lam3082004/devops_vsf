# App Service Plan + Web App + slot staging.
#
# P0v3 chứ không phải Basic: Basic không có deployment slot (M2) và autoscale (M7).
# P0v3 0.0915 USD/giờ còn rẻ hơn S1 0.095 (Retail API, SEA, 15/09).
resource "azurerm_service_plan" "app" {
  name                = "asp-${var.project}-${var.env}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  os_type             = "Linux"
  sku_name            = "P0v3"
  worker_count        = 1
  tags                = local.tags

  # D19 quyết định A: Terraform chỉ đặt số instance BAN ĐẦU, lúc chạy thì
  # autoscale (autoscale.tf) sở hữu nó. Thiếu dòng này thì khi autoscale đang
  # ở 2 instance, `plan` báo drift 2 → 1 và `apply` lúc đó kéo plan về 1 giữa
  # lúc tải cao — Terraform và autoscale đánh nhau.
  lifecycle {
    ignore_changes = [worker_count]
  }
}

locals {
  # Dùng chung cho production và staging: slot phải giống hệt site để swap
  # không mang cấu hình lạ lên production.
  app_settings = {
    # App Service chuyển traffic vào cổng này của container.
    WEBSITES_PORT = tostring(var.container_port)
    # Không mount /home dùng chung vào container: app không ghi file, tắt đi
    # để container khởi động nhanh và không phụ thuộc storage của stamp.
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"

    # Kết nối MySQL (D12 mục 1). App fail-fast nếu thiếu một trong các biến này.
    DB_HOST = azurerm_mysql_flexible_server.db.fqdn
    DB_NAME = var.db_name
    DB_USER = azurerm_mysql_flexible_server.db.administrator_login
    DB_TLS  = "true"
    # Key Vault reference, URI KHÔNG kèm version để nhận bản mới khi xoay vòng.
    # Không có secret plaintext nào trong app settings (M4).
    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mysql_admin_password.versionless_id})"

    # D17: warm-up trước khi swap (docs/guides/d17-safe-swap.md mục 1) — nền
    # tảng gọi path này vào slot đích SAU khi áp cấu hình production, TRƯỚC
    # khi đổi định tuyến. `WEBSITE_SWAP_WARMUP_PING_STATUSES` cố ý CHỈ "200":
    # `/health` trả 503 khi không ping được DB (Services/HealthService.cs) —
    # nếu 503 cũng được coi là "đã phản hồi" thì swap đưa lên production một
    # bản không nói chuyện được với DB. Rộng hơn (để trống) thì cả 404 do path
    # sai cũng qua — bẫy thứ 3 của guide.
    WEBSITE_SWAP_WARMUP_PING_PATH     = "/health"
    WEBSITE_SWAP_WARMUP_PING_STATUSES = "200"
  }

  # Luật truy cập theo IP (M6), dùng chung cho production và slot staging —
  # slot mà quên khai thì staging vẫn mở ra Internet, một nửa bài coi như hỏng.
  # priority 100, 110, 120… theo thứ tự tên luật; keys() luôn trả về đã sắp xếp
  # nên cùng một map cho ra cùng bộ số, không nhảy giữa hai lần apply.
  ip_rules = {
    for name, cidr in var.allowed_ips : name => {
      ip_address = cidr
      priority   = 100 + index(keys(var.allowed_ips), name) * 10
    }
  }
}

resource "azurerm_linux_web_app" "app" {
  # local.be_app_name (locals.tf), KHÔNG nội suy trực tiếp ở đây: `fe`
  # (app-fe.tf) cần đúng chuỗi này để tính API_BASE_URL mà không đọc
  # default_hostname — hai chỗ tính cùng một local để không lệch nhau
  # (D16 Việc 2).
  name                = local.be_app_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  service_plan_id     = azurerm_service_plan.app.id
  tags                = local.tags

  https_only = true
  # D2 thấy Portal tắt sẵn basic auth cho FTP/SCM; Terraform phải khai rõ.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = local.app_settings

  # Danh tính dùng để resolve @Microsoft.KeyVault(...). Bỏ trống thì nền tảng
  # dùng system-assigned (không tồn tại) → reference không resolve (D12).
  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id

  # Role Secrets User phải có trước khi app resolve reference, nếu không
  # reference đỏ cho tới khi restart.
  depends_on = [azurerm_role_assignment.kv_secrets_user_app]

  site_config {
    always_on           = true # không cold start; slot/swap warm-up cần app luôn chạy
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Pull image từ ACR bằng user-assigned identity, chỉ định client ID (bỏ trống
    # thì dùng system-assigned → pull lỗi). Không dùng admin/password của ACR (M1).
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    # M6: mặc định chặn, chỉ IP trong var.allowed_ips được vào. Đọc CẢNH BÁO ở
    # variables.tf trước khi apply với map rỗng.
    #
    # `description` KHÔNG được chứa dấu `,` hay `;` — Azure trả 400 BadRequest
    # `IpSecurityRestriction.Description has an invalid value`. `terraform
    # validate` không bắt được, chỉ lộ ra lúc apply (ai-failure-log.md #23).
    ip_restriction_default_action = "Deny"
    # Kudu/SCM dùng CHUNG danh sách với site chính (Decision A). Để danh sách SCM
    # riêng thì quên khai allow là tự khoá mình khỏi Kudu — D3 đã dính đúng bẫy
    # này khi làm bằng CLI (notes/d3-cli.md:34-36).
    scm_use_main_ip_restriction = true
    # CẢ HAI dòng mới khoá được SCM. `scm_use_main_ip_restriction` chỉ cho SCM
    # dùng lại DANH SÁCH LUẬT của site chính, KHÔNG kéo theo hành động mặc định:
    # `scm_ip_restriction_default_action` vẫn là "Allow", nên IP không khớp luật
    # nào sẽ rơi xuống Allow và vào được Kudu. Đo được ở D13: cùng một IP ngoài
    # whitelist, cùng thời điểm — site chính 403 còn SCM trả 200 với token ARM
    # (evidence/M6.md). Thiếu dòng dưới đây thì Kudu mở ra Internet trong khi
    # `az ... access-restriction show` nhìn vẫn như đã khoá.
    scm_ip_restriction_default_action = "Deny"

    # local.be_ip_rules (locals.tf), KHÔNG local.ip_rules: `be` phải thêm allow
    # outbound IP của `fe` ngoài IP nhà, nếu không mọi lời gọi API từ `fe`
    # nhận 403 (D16 Việc 2, notes/d16-prep.md mục "vấp #1"). `fe`/`fe_staging`
    # (app-fe.tf) vẫn dùng local.ip_rules thường — chỉ `be` mới cần mở thêm.
    dynamic "ip_restriction" {
      for_each = local.be_ip_rules
      content {
        name       = ip_restriction.key
        ip_address = ip_restriction.value.ip_address
        action     = "Allow"
        priority   = ip_restriction.value.priority
        # HAI ràng buộc của Azure cho trường này, `plan` KHÔNG bắt được cái nào,
        # cả hai chỉ nổ lúc apply sau khi đã mất vài phút:
        #   1. không được chứa `,` hay `;` (ai-failure-log.md #23)
        #   2. TỐI ĐA 64 BYTE — "Description exceeds 64 characters" (400
        #      BadRequest). Bản đầu của dòng dưới dài đúng 65 byte và làm hỏng
        #      `make up` ở pha 2 (D16, ai-failure-log.md). Chuỗi của D13 chỉ 55
        #      byte nên trước giờ chưa ai va phải. Dấu tiếng Việt tính NHIỀU
        #      byte hơn một ký tự — đếm bằng byte, đừng đếm bằng mắt.
        # Rule outbound của fe có mô tả riêng để phân biệt trên Portal với IP
        # nhà khai trong tfvars.
        description = startswith(ip_restriction.key, "fe-outbound-") ? "M6 (D16) - outbound IP cua fe (locals.tf)" : "M6 (D13) — IP khai trong terraform.tfvars ngoài repo"
      }
    }

    # D17 (P1, notes/d17-prep.md "Bảng bẫy"): health check + warm-up (app_settings
    # ở trên) bật TỪ LÚC apply, kể cả khi ACR còn trống và cả 4 bề mặt đang chạy
    # image mẫu (dotnet/samples:aspnetapp — KHÔNG có /health, trả 404). Hệ quả:
    # instance "unhealthy" từ lúc `make up` tới lần CD đầu tiên đẩy image thật.
    # Một instance (worker_count = 1) thì không bị loại — nền tảng chỉ thay
    # instance khi unhealthy QUÁ 1 GIỜ liên tục — nên chấp nhận được miễn cửa sổ
    # từ `make up` tới lần deploy đầu tiên ngắn hơn 1 giờ. KHÔNG đổi path này để
    # khớp placeholder: health check phải đo đúng app thật, không phải app mẫu.
    #
    # eviction_time_in_min = 5: khoảng cho phép là 2–10 (schema provider, xem
    # `terraform providers schema -json`). Chọn 5 (giữa khoảng) — đủ dài để
    # không loại instance vì một lần health check trượt do cold start/deploy
    # tạm thời, đủ ngắn để một instance thật sự hỏng không phục vụ traffic lâu.
    # Chưa có số đo tải thật (M7 autoscale) để tinh chỉnh hơn — ghi vào notes/d17.md.
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5

    # Image mẫu công khai (cùng cổng 8080 với app thật): ACR trống lúc dựng môi
    # trường. Registry URL + image sau đó do tay/CD đặt sang ACR (D11, D16);
    # ignore_changes bên dưới giữ Terraform khỏi đảo ngược.
    application_stack {
      docker_registry_url = "https://mcr.microsoft.com"
      docker_image_name   = var.placeholder_image
    }
  }

  lifecycle {
    # Từ D11, CD (D16) đổi tag image thẳng trên Azure sau mỗi lần build —
    # KHÔNG qua Terraform. Thiếu ignore_changes này, apply kế tiếp sẽ thấy
    # image trên Azure khác var.placeholder_image trong code và ĐẢO NGƯỢC về
    # placeholder, sập bản đang chạy. Từ nay: Terraform sở hữu mọi thứ của
    # Web App trừ registry URL + tag image; CD sở hữu registry URL + tag image (Decision, notes/d9.md, notes/d11-prep.md).
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      site_config[0].application_stack[0].docker_registry_url,
    ]
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  # Hostname: app-vsf-xxxxxx-staging.azurewebsites.net — 22 ký tự, dưới giới hạn 60.
  name           = "staging"
  app_service_id = azurerm_linux_web_app.app.id
  tags           = local.tags

  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # CÙNG identity với production — thiếu khối này thì D11 slot staging pull image lỗi.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = local.app_settings

  # Danh tính dùng để resolve @Microsoft.KeyVault(...). Bỏ trống thì nền tảng
  # dùng system-assigned (không tồn tại) → reference không resolve (D12).
  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id

  # Role Secrets User phải có trước khi app resolve reference, nếu không
  # reference đỏ cho tới khi restart.
  depends_on = [azurerm_role_assignment.kv_secrets_user_app]

  site_config {
    always_on           = true
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Pull image từ ACR bằng user-assigned identity, chỉ định client ID (bỏ trống
    # thì dùng system-assigned → pull lỗi). Không dùng admin/password của ACR (M1).
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    # M6 cho slot staging — bốn bề mặt phải chặn, không phải hai: site chính,
    # SCM của site chính, slot staging, SCM của slot.
    # `scm_ip_restriction_default_action` phải khai riêng: xem giải thích dài ở
    # site chính bên trên, thiếu nó thì Kudu của slot vẫn mở.
    ip_restriction_default_action     = "Deny"
    scm_use_main_ip_restriction       = true
    scm_ip_restriction_default_action = "Deny"

    # local.be_ip_rules, giống site chính bên trên — slot staging cũng là
    # `be` (swap lên production), phải mở cho outbound IP của `fe` như nhau.
    dynamic "ip_restriction" {
      for_each = local.be_ip_rules
      content {
        name       = ip_restriction.key
        ip_address = ip_restriction.value.ip_address
        action     = "Allow"
        priority   = ip_restriction.value.priority
        # Tối đa 64 byte, không `,`/`;` — xem giải thích dài ở site chính.
        description = startswith(ip_restriction.key, "fe-outbound-") ? "M6 (D16) - outbound IP cua fe (locals.tf)" : "M6 (D13) — IP khai trong terraform.tfvars ngoài repo"
      }
    }

    # D17: cùng path/eviction với site chính ở trên (P1 — cùng hệ quả placeholder,
    # cùng lý do không đổi path để khớp placeholder). Slot staging là nơi CD đặt
    # image THẬT trước swap nên đây chính là bề mặt warm-up ping vào.
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5

    # Khai image cho slot một cách tường minh: D2 thấy clone slot KHÔNG copy
    # image → slot rỗng trả 503, swap lên là production chết.
    application_stack {
      docker_registry_url = "https://mcr.microsoft.com"
      docker_image_name   = var.placeholder_image
    }
  }

  lifecycle {
    # Cùng lý do với production ở trên — slot staging là nơi CD đổi tag TRƯỚC
    # khi swap (D16/D17), Terraform không được đảo nó về placeholder.
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      site_config[0].application_stack[0].docker_registry_url,
    ]
  }
}

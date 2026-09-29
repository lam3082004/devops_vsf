# Web App `fe` (Next.js, OpsBoard) + slot staging. File RIÊNG với app.tf (đã dài) —
# cùng service_plan_id và cùng identity với `be`, không tạo plan/identity mới
# (D16, notes/d16-prep.md — Q10: không thêm tiền plan).

locals {
  # KHÔNG dùng lại local.app_settings (app.tf): nó có DB_HOST/DB_USER/DB_PASSWORD
  # của `be` — `fe` không nói chuyện với MySQL và không được có secret nào liên
  # quan tới DB trong app settings của nó.
  #
  # D17: mọi key ở đây dùng chung site + slot, TRỪ API_BASE_URL — key đó được
  # `merge()` riêng cho slot staging (azurerm_linux_web_app_slot.fe_staging bên
  # dưới) và khai sticky trên site chính, để đóng known-issues.md #15.
  fe_app_settings = merge({
    # App Service chuyển traffic vào cổng này của container (cùng ý nghĩa với
    # local.app_settings.WEBSITES_PORT ở app.tf, nhưng var.fe_container_port
    # khác var.container_port — xem comment ở variables.tf).
    WEBSITES_PORT = tostring(var.fe_container_port)
    # Không mount /home dùng chung: fe không ghi file, tắt để container khởi
    # động nhanh và không phụ thuộc storage của stamp — giống lý do ở be.
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"

    # Địa chỉ backend cho route handler phía server gọi (app/fe/src/lib/api.ts).
    # local.be_hostname (locals.tf) tính TAY từ tên, KHÔNG
    # azurerm_linux_web_app.app.default_hostname — đọc default_hostname ở đây
    # tạo cạnh fe→be, cộng cạnh be→fe (be cần outbound IP của fe, xem
    # local.be_ip_rules) thành `Cycle:` (D16 Việc 2).
    #
    # D17 (#15): giá trị NÀY chỉ còn dùng cho site chính (production). Slot
    # staging GHI ĐÈ key này sang local.be_staging_hostname bằng merge() ở
    # azurerm_linux_web_app_slot.fe_staging bên dưới — trước D17 cả hai slot
    # dùng chung map này nên `fe` staging luôn gọi `be` PRODUCTION (bản cũ)
    # trong lúc warm-up, không bao giờ thử được với `be` staging (bản mới)
    # trước khi swap. `sticky_settings` trên site chính (dưới resource "fe")
    # giữ cho lần swap đầu tiên KHÔNG mang giá trị staging này lên production.
    API_BASE_URL = "https://${local.be_hostname}"

    # Image PLACEHOLDER lúc ACR còn trống (dotnet/samples:aspnetapp, một app
    # .NET) mặc định nghe cổng 8080, không phải 3000 — đặt ASPNETCORE_HTTP_PORTS
    # để nó nghe đúng WEBSITES_PORT=3000 từ lúc `make up` cho tới lần CD đầu
    # tiên đẩy image Next.js thật sang. Thiếu biến này, placeholder vẫn nghe
    # 8080 trong khi App Service gõ cổng 3000 → fe trả 503 ngay từ đầu, và vì
    # đây là hành vi của IMAGE MẪU (không phải bug code fe) nên rất dễ bị điều
    # tra nhầm sang cấu hình Next.js. Next.js thật (app/fe/Dockerfile) không
    # đọc biến này — nó tự nghe cổng theo ENV PORT=3000 khai sẵn trong image —
    # nên đặt luôn, vô hại với image thật, cứu image mẫu.
    ASPNETCORE_HTTP_PORTS = tostring(var.fe_container_port)

    # D17: warm-up trước khi swap, cùng cơ chế với `be` (app.tf) nhưng path
    # khác — quyết định A (notes/d17-prep.md): `fe` KHÔNG có `/health`, chỉ
    # `/api/version` (chứng minh process sống). KHÔNG dùng `/api/health` (route
    # mới, quyết định B) làm warm-up path: route đó gọi sang `be`, và nếu `be`
    # đang chậm/degraded thì warm-up của `fe` cũng thất bại theo — restart hay
    # giữ `fe` lại ở staging không chữa được `be`, chỉ làm swap `fe` bị chặn
    # oan vì lỗi của một app khác.
    WEBSITE_SWAP_WARMUP_PING_PATH     = "/api/version"
    WEBSITE_SWAP_WARMUP_PING_STATUSES = "200"
    }, var.enable_app_insights ? {
    # D21 (quyết định F): tracing `fe` → cùng App Insights với `be` (src/instrumentation.node.ts).
    # Cùng secret, cùng cách dựng URI với `be` (app.tf — lý do không đọc versionless_id ở đó).
    # Đây là secret DUY NHẤT `fe` đọc từ Key Vault; app tắt telemetry (không thoát) nếu
    # tham chiếu chưa resolve.
    APPLICATIONINSIGHTS_CONNECTION_STRING = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.kv.vault_uri}secrets/${local.appinsights_secret_name})"
  } : {})
}

resource "azurerm_linux_web_app" "fe" {
  name                = "fe-${var.project}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  service_plan_id     = azurerm_service_plan.app.id
  tags                = local.tags

  https_only = true
  # Giống `be`: Portal tắt sẵn basic auth cho FTP/SCM, Terraform khai rõ.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  app_settings = local.fe_app_settings

  # D21: `fe` đọc đúng một secret (connection string App Insights, tracing) — danh tính
  # resolve @Microsoft.KeyVault(...) giống `be`. Trước D21 bỏ trống vì `fe` không có secret nào.
  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id

  # Role Secrets User và secret phải có trước khi app resolve reference — cùng lý do `be`.
  depends_on = [
    azurerm_role_assignment.kv_secrets_user_app,
    azurerm_key_vault_secret.appinsights_connection_string,
  ]

  # D17 (#15): API_BASE_URL PHẢI sticky. Site chính và slot staging cố ý có
  # GIÁ TRỊ KHÁC NHAU cho key này (production trỏ `be` production, staging trỏ
  # `be` staging — merge() ở fe_staging bên dưới); nếu quên sticky thì lần swap
  # ĐẦU TIÊN mang giá trị của staging lên production, `fe` production sẽ gọi
  # nhầm sang `be` staging mà không ai báo lỗi (chỉ có dữ liệu "lạ"). Chỉ khối
  # này ở `sticky_settings` — không có `connection_string_names` vì `fe` không
  # có connection string nào. Block này CHỈ tồn tại ở site chính (schema
  # provider: `sticky_settings` không có trên `azurerm_linux_web_app_slot`,
  # xác nhận bằng `terraform providers schema -json` — sticky là thuộc tính
  # của SLOT SETTING khai trên site, không phải khai lại trên từng slot).
  sticky_settings {
    app_setting_names = ["API_BASE_URL"]
  }

  site_config {
    always_on           = true # không cold start; slot/swap warm-up cần app luôn chạy
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Pull image từ ACR bằng user-assigned identity, chỉ định client ID (bỏ
    # trống thì dùng system-assigned → pull lỗi). Không dùng admin/password
    # của ACR (M1) — giống `be`.
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    # M6 cho fe: mặc định chặn, chỉ IP trong var.allowed_ips được vào —
    # local.ip_rules THƯỜNG, không local.be_ip_rules. `fe` là thứ người dùng
    # mở bằng trình duyệt, không phải thứ `be` gọi tới, nên không cần (và
    # không được) thêm outbound IP của bất kỳ app nào vào đây.
    #
    # `description` KHÔNG được chứa dấu `,` hay `;` — Azure trả 400 BadRequest
    # `IpSecurityRestriction.Description has an invalid value`. `terraform
    # validate` không bắt được, chỉ lộ ra lúc apply (ai-failure-log.md #23).
    ip_restriction_default_action = "Deny"
    # Kudu/SCM dùng CHUNG danh sách với site chính (Decision A, giống `be`).
    scm_use_main_ip_restriction = true
    # CẢ HAI dòng mới khoá được SCM. `scm_use_main_ip_restriction` chỉ cho SCM
    # dùng lại DANH SÁCH LUẬT của site chính, KHÔNG kéo theo hành động mặc
    # định: `scm_ip_restriction_default_action` vẫn là "Allow" nếu bỏ trống,
    # nên IP không khớp luật nào sẽ rơi xuống Allow và vào được Kudu. Đọc lại
    # comment dài ở app.tf:96-103 (D13 đo được đúng lỗ này) — thiếu dòng dưới
    # đây là Kudu của fe mở ra Internet trong khi site chính nhìn vẫn như đã
    # khoá.
    scm_ip_restriction_default_action = "Deny"

    dynamic "ip_restriction" {
      for_each = local.ip_rules
      content {
        name        = ip_restriction.key
        ip_address  = ip_restriction.value.ip_address
        action      = "Allow"
        priority    = ip_restriction.value.priority
        description = "M6 (D16) — IP khai trong terraform.tfvars ngoài repo"
      }
    }

    # D17 (P1, notes/d17-prep.md "Bảng bẫy"): quyết định A — health check nền
    # tảng của `fe` là `/api/version`, KHÔNG phải `/api/health` (route mới,
    # quyết định B). `/api/health` gọi sang `be`; dùng nó làm health check thì
    # `be` hỏng sẽ kéo theo `fe` bị nền tảng coi là unhealthy và RESTART —
    # restart `fe` không chữa được `be`, chỉ làm tệ thêm (mất luôn `fe` đang
    # chạy tốt trong lúc `be` đang lỗi). `/api/version` chỉ chứng minh process
    # còn sống — đúng phạm vi của health check nền tảng. eviction 5 phút,
    # cùng lý do với `be` (app.tf) — image mẫu chưa có route này nên cũng dính
    # P1 (unhealthy tới lần CD đầu tiên, chấp nhận được vì < 1 giờ).
    health_check_path                 = "/api/version"
    health_check_eviction_time_in_min = 5

    # Image mẫu công khai lúc ACR còn trống; registry URL + tag image sau đó
    # do CD (D16 bước 3) đặt thẳng trên Azure. Cùng lý do với `be` (app.tf).
    # ASPNETCORE_HTTP_PORTS ở local.fe_app_settings giữ placeholder nghe đúng
    # cổng 3000 thay vì 8080 mặc định của nó.
    application_stack {
      docker_registry_url = "https://mcr.microsoft.com"
      docker_image_name   = var.placeholder_image
    }
  }

  lifecycle {
    # CD (D16) đổi tag image thẳng trên Azure sau mỗi lần build — KHÔNG qua
    # Terraform. Thiếu ignore_changes này, apply kế tiếp sẽ thấy image trên
    # Azure khác var.placeholder_image trong code và ĐẢO NGƯỢC về placeholder,
    # sập bản đang chạy — giống `be` (app.tf:126-136, Decision notes/d9.md,
    # notes/d11-prep.md).
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      site_config[0].application_stack[0].docker_registry_url,
    ]
  }
}

resource "azurerm_linux_web_app_slot" "fe_staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.fe.id
  tags           = local.tags

  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # CÙNG identity với production — thiếu khối này thì slot staging pull image
  # lỗi (D11, giống `be`).
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  # D17 (#15): merge() đè riêng API_BASE_URL sang local.be_staging_hostname
  # (locals.tf) — slot staging của `fe` phải gọi slot staging của `be`, không
  # phải `be` production, để có một cửa sổ thật sự thử "bản mới nói chuyện
  # với bản mới" TRƯỚC khi swap (trước D17: known-issues.md #15). Đây là lý do
  # `fe` không thể dùng chung nguyên vẹn local.fe_app_settings cho cả site lẫn
  # slot như mọi key khác — sticky_settings trên site chính (ở trên) giữ cho
  # swap không mang giá trị này lên production.
  app_settings = merge(local.fe_app_settings, {
    API_BASE_URL = "https://${local.be_staging_hostname}"
  })

  # Giống site chính ở trên (D21): slot cũng resolve connection string App Insights.
  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id

  depends_on = [
    azurerm_role_assignment.kv_secrets_user_app,
    azurerm_key_vault_secret.appinsights_connection_string,
  ]

  site_config {
    always_on           = true
    http2_enabled       = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    # M6 cho slot staging của fe — bốn bề mặt phải chặn: site chính, SCM của
    # site chính, slot staging, SCM của slot (giống `be`, app.tf:176-177).
    ip_restriction_default_action     = "Deny"
    scm_use_main_ip_restriction       = true
    scm_ip_restriction_default_action = "Deny"

    dynamic "ip_restriction" {
      for_each = local.ip_rules
      content {
        name        = ip_restriction.key
        ip_address  = ip_restriction.value.ip_address
        action      = "Allow"
        priority    = ip_restriction.value.priority
        description = "M6 (D16) — IP khai trong terraform.tfvars ngoài repo"
      }
    }

    # D17: cùng path/eviction với site chính ở trên (P1 — cùng hệ quả
    # placeholder). Slot staging là nơi CD đặt image THẬT trước swap nên đây
    # chính là bề mặt warm-up ping vào.
    health_check_path                 = "/api/version"
    health_check_eviction_time_in_min = 5

    # Khai image cho slot một cách tường minh: clone slot KHÔNG copy image →
    # slot rỗng trả 503, swap lên là production chết (D2, giống `be`).
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

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

  # Tên + hostname của `be` tính TAY (chuỗi biết trước lúc plan, không phải
  # attribute "known after apply") thay vì đọc
  # azurerm_linux_web_app.app.default_hostname. Lý do (D16 Việc 2): `fe` cần
  # API_BASE_URL trỏ sang `be` (app-fe.tf), và `be` cần allow outbound IP của
  # `fe` trong ip_restriction (local.be_ip_rules dưới) — tức đã có cạnh
  # be→fe. Nếu `fe` lại đọc default_hostname thật của `app` thay vì hằng số
  # local.be_hostname này thì có thêm cạnh fe→be, khép thành `Cycle:`. Tính
  # hostname từ tên biết trước cắt đứt cạnh fe→be, chỉ còn lại đúng một cạnh
  # be→fe.
  be_app_name = "app-${var.project}-${local.name_suffix}"
  be_hostname = "${local.be_app_name}.azurewebsites.net"

  # D17 (#15): hostname slot staging của `be`, tính TAY như be_hostname ở trên —
  # KHÔNG đọc azurerm_linux_web_app_slot.staging.default_hostname. Lý do giống
  # hệt be_hostname: đọc attribute thật của slot staging (app.tf) từ đây sẽ mở
  # lại đúng cạnh fe→be mà be_hostname đã cắt (D16 Việc 2), khép thành `Cycle:`.
  # Tên slot mặc định của Azure Web App luôn là "<app>-staging" nên tính được
  # trước lúc plan, giống be_hostname.
  be_staging_hostname = "${local.be_app_name}-staging.azurewebsites.net"

  # M6 cho `be`, MỞ RỘNG so với local.ip_rules (app.tf): ngoài IP nhà, phải
  # allow cả outbound IP của `fe`. `fe` gọi `be` từ phía server (BFF,
  # app/fe/src/lib/api.ts) nên request đi ra Internet rồi vòng lại bằng
  # outbound IP của App Service, không đi đường nội bộ — không allow thì mọi
  # trang gọi API của `fe` nhận 403 từ `be` (notes/d16-prep.md, mục "vấp #1").
  #
  # Đánh đổi CỐ Ý, ghi lại vì đây là nới lỏng thật: outbound IP dùng chung cho
  # CẢ SCALE UNIT (mọi App Service khác cùng stamp Azure, không riêng gì `fe`
  # của bài này) — allow các IP này nghĩa là app của khách hàng khác cùng
  # stamp cũng gõ được vào `be`. Đúng hạn chế đã nêu ở cuối evidence/M3.md cho
  # firewall MySQL, nay lặp lại ở tầng HTTP. Chấp nhận được vì R5 đã chốt
  # (Decision 2026-09-21): `be`/`fe` là công cụ nội bộ, M6 chỉ yêu cầu chặn
  # theo IP; muốn chặt hơn phải VNet integration + Private Endpoint (S3 trong
  # topic.md).
  #
  # priority bắt đầu từ 300, KHÔNG nối tiếp dải 100/110/... của local.ip_rules:
  # nếu cộng thêm sau số IP nhà hiện có thì thêm/bớt một IP nhà sẽ làm priority
  # của MỌI rule outbound nhảy số giữa hai lần apply (replace hàng loạt dù
  # hành vi không đổi). Dải riêng giữ hai tập số độc lập với nhau.
  # sort() trước index(): possible_outbound_ip_address_list không cam kết thứ
  # tự ổn định giữa hai lần apply; sort() ép nó ổn định — cùng lý do keys() đã
  # tự sort ở app.tf:37-38.
  be_fe_outbound_ip_rules = {
    for i, ip in sort(azurerm_linux_web_app.fe.possible_outbound_ip_address_list) :
    "fe-outbound-${replace(ip, ".", "-")}" => {
      ip_address = "${ip}/32"
      priority   = 300 + i * 10
    }
  }

  be_ip_rules = merge(local.ip_rules, local.be_fe_outbound_ip_rules)
}

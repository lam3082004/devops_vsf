variable "location" {
  description = "Region cho App Service Plan, Web App, ACR, Key Vault, identity."
  type        = string
  # Đổi từ southeastasia sang centralindia 2026-09-19/20: subscription này bị
  # Azure throttle riêng cho thao tác tạo App Service Plan ở southeastasia
  # (429 "throttled for subscription", 7 lần thử/26 tiếng không đổi — không
  # phải giới hạn chung của subscription, xác nhận bằng az cli tạo P0v3 thành
  # công ngay tại centralindia). Chi tiết: notes/d9.md, known-issues.md #6.
  default = "centralindia"
}

variable "secrets_writer_object_id" {
  description = "Object ID của người/identity được cấp Key Vault Secrets Officer để ghi secret."
  type        = string
  # Trước đây dùng data.azurerm_client_config.current.object_id ("ai đang
  # chạy Terraform") — SAI: giá trị này đổi theo danh tính đang authenticate,
  # nên id-gh-plan (chạy plan trong CI, chỉ Reader) chạy plan cũng thấy
  # "principal_id đổi" → Terraform đòi replace role assignment, và replace
  # lại cần quyền ghi mà id-gh-plan không có → CI đỏ 403 dù chỉ plan. Phát
  # hiện khi PR #11 chạy CI lần đầu trên state đã có Web App thật (trước giờ
  # CI luôn ở nhánh "pha 1", chưa từng full-refresh resource này). Pin cứng
  # về object id thật của người vận hành — ổn định bất kể ai chạy plan/apply.
  default = "42330cda-5378-4f7e-bf4b-608ab2e632ec" # BUI TUNG LAM (az ad signed-in-user show)
}

variable "db_location" {
  description = "Region riêng cho MySQL Flexible Server."
  type        = string
  # KHÔNG dùng chung var.location: subscription này bị Azure từ chối tạo
  # MySQL Flexible ở centralindia (ProvisionNotSupportedForRegion — khác hẳn
  # lỗi throttle của App Service Plan, đây là subscription chưa được cấp
  # quyền MySQL Flexible ở vùng đó). southeastasia đã tạo MySQL thành công
  # nhiều lần (D2, D3, D8) nên giữ nguyên ở đó. Đánh đổi: Web App và MySQL
  # khác region → thêm ~vài chục ms latency mỗi query, chấp nhận được cho môi
  # trường học/dev. Resource Group vẫn là 1, chỉ khác location của riêng
  # resource MySQL — Azure cho phép resource nằm khác region với RG chứa nó.
  default = "southeastasia"
}

variable "project" {
  description = "Tiền tố đặt tên và giá trị tag project."
  type        = string
  default     = "vsf"
}

variable "env" {
  description = "Tên môi trường, dùng trong tên resource và tag."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Người chịu trách nhiệm, dùng cho tag và truy vết chi phí."
  type        = string
  default     = "intern"
}

variable "placeholder_image" {
  description = "Image công khai trên mcr.microsoft.com chạy tạm lúc dựng môi trường; sau đó image do CD/tay đặt (D11, D16). Phải nghe cùng cổng với container_port."
  type        = string
  default     = "dotnet/samples:aspnetapp"
}

variable "container_port" {
  description = "Cổng container lắng nghe (WEBSITES_PORT). Cả image mẫu aspnetapp lẫn app thật đều dùng 8080."
  type        = number
  default     = 8080
}

variable "fe_container_port" {
  description = "Cổng container của fe (WEBSITES_PORT). Khác var.container_port vì app/fe/Dockerfile đặt ENV PORT=3000 (Next.js standalone) — be nghe 8080, fe nghe 3000, dùng chung biến là fe health check hỏng ngay (D16, notes/d16-prep.md mục 'vấp #2')."
  type        = number
  default     = 3000
}

variable "db_name" {
  description = "Tên database của app trên MySQL Flexible."
  type        = string
  default     = "appdb"
}

variable "allowed_ips" {
  description = "Danh sách IP được vào app và Kudu (M6). Khoá = tên luật, giá trị = CIDR IPv4. Giá trị cá nhân — khai trong infra/app/terraform.tfvars (KHÔNG commit), mẫu ở terraform.tfvars.example."
  type        = map(string)
  # map chứ không phải list: đổi thứ tự hay thêm một IP không làm lệch tên luật,
  # cùng lý do đã chọn for_each cho firewall MySQL ở D8.
  #
  # CẢNH BÁO: rỗng + ip_restriction_default_action = "Deny" (app.tf) = KHOÁ TẤT
  # CẢ, kể cả chính mình — chỉ gỡ được qua Portal. Kiểm terraform.tfvars có IP
  # trước khi apply. CI chạy plan KHÔNG có tfvars nên luôn thấy map rỗng; plan
  # của CI vì thế sẽ báo "xoá luật" khi môi trường thật đang bật — đó là hệ quả
  # đã biết của việc không commit IP, không phải drift thật.
  #
  # Chỉ khai IPv4 (Decision C của notes/d13-prep.md): mạng có IPv6 thì request
  # đi bằng IPv6 sẽ không khớp luật IPv4 → tự nhận 403. Khi test luôn ép curl -4.
  default = {}
}

# Hai công tắc dưới đây CHỈ để lấy bằng chứng "chứng minh ngược" của M1 và M5:
# gỡ quyền của managed identity rồi chứng minh app gãy, sau đó trả lại. Luôn để
# mặc định true trong code; đặt false bằng `-var` ngay trên dòng lệnh, đúng một
# lần đo, rồi apply lại không có `-var` để trả quyền. Làm cách này thay vì gỡ
# tay trên Portal: gỡ tay tạo drift phải nhớ xoá, còn ở đây `terraform plan`
# sau khi đo xong phải ra No changes thì mới coi là đã dọn sạch.

variable "grant_app_keyvault_access" {
  description = "Gán role Key Vault Secrets User cho identity của app. Đặt false CHỈ khi đang đo M5 (app phải gãy khi mất quyền đọc Key Vault)."
  type        = bool
  default     = true
}

variable "grant_app_acr_pull" {
  description = "Gán role AcrPull cho identity của app. Đặt false CHỈ khi đang đo chứng minh ngược của M1 (app phải không pull được image)."
  type        = bool
  default     = true
}

variable "enable_app_insights" {
  description = "Dựng Application Insights + secret connection string + app setting cho `be` và `fe` (D20, D21). TẠM theo mặc định Q1 — mentor nói không thì đặt false (workspace Log Analytics vẫn giữ cho D21)."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email nhận alert (action group ag-vsf-oncall, D22). Giá trị cá nhân — khai trong infra/app/terraform.tfvars (KHÔNG commit), như allowed_ips."
  type        = string
  # Rỗng = action group không có người nhận: alert vẫn bắn (thấy trên Portal/Workbook) nhưng
  # không ai nhận email. CI chạy plan KHÔNG có tfvars nên luôn thấy rỗng → plan của CI báo
  # "xoá email_receiver" khi môi trường thật đang bật — diff giả đã biết, cùng loại với
  # ip_restriction (xem allowed_ips ở trên).
  default = ""
}

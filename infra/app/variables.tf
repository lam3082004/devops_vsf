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
  description = "Image công khai trên mcr.microsoft.com chạy tạm cho tới khi có ACR (D11)."
  type        = string
  default     = "appsvc/staticsite:latest"
}

variable "container_port" {
  description = "Cổng container lắng nghe (WEBSITES_PORT). Image mẫu dùng 80; app thật dùng 8080 (D11)."
  type        = number
  default     = 80
}

variable "db_name" {
  description = "Tên database của app trên MySQL Flexible."
  type        = string
  default     = "appdb"
}

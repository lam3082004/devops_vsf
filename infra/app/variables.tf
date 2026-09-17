variable "location" {
  description = "Region cho toàn bộ resource của môi trường app."
  type        = string
  default     = "southeastasia"
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

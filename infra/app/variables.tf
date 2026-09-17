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

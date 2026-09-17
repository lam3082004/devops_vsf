variable "location" {
  description = "Region cho mọi resource của bootstrap."
  type        = string
  default     = "southeastasia"
}

variable "project" {
  description = "Tiền tố đặt tên và tag."
  type        = string
  default     = "vsf"
}

variable "owner" {
  description = "Người chịu trách nhiệm, dùng cho tag và truy vết chi phí."
  type        = string
  default     = "intern"
}

variable "github_repo" {
  description = "Repo GitHub dạng owner/name, dùng cho federated credential."
  type        = string
  default     = "lam3082004/devops_vsf"
}

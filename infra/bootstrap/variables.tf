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

variable "github_owner_id" {
  description = <<-EOT
    ID số của tài khoản GitHub. Lấy bằng: gh api user --jq .id
    Cần vì GitHub đã bật "immutable subject": token OIDC mang subject dạng
    repo:<owner>@<owner_id>/<repo>@<repo_id>:<context> — đổi tên repo/user
    không làm hỏng xác thực, nhưng subject khai theo tên thì không khớp.
  EOT
  type        = string
  default     = "67915284"
}

variable "github_repo_id" {
  description = "ID số của repo. Lấy bằng: gh api repos/<owner>/<repo> --jq .id"
  type        = string
  default     = "1371039109"
}

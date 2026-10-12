variable "location" {
  description = "Region cho cluster AKS và mọi resource của root này."
  type        = string
  # KHÔNG dùng chung region với infra/app (đo 12/10, az chỉ đọc):
  #   centralindia  — quota 4 vCPU đã dùng 4/4 (2 VM của một PoC khác chung subscription)
  #   southeastasia — D-series `NotAvailableForSubscription` ở cấp Location
  #   eastasia      — D2as_v5 không hạn chế, cores 0/4, public IP 0/3
  # Subscription Free Trial không xin tăng quota được. Hệ quả: `be` (East Asia) gọi
  # MySQL (Southeast Asia) và pull ACR (Central India) đều liên vùng.
  default = "eastasia"
}

variable "project" {
  description = "Tiền tố đặt tên và giá trị tag project. Phải trùng infra/app."
  type        = string
  default     = "vsf"
}

variable "env" {
  description = "Tên môi trường. Phải trùng infra/app (dùng để tìm rg-<project>-<env>)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Người chịu trách nhiệm, dùng cho tag và truy vết chi phí."
  type        = string
  default     = "intern"
}

variable "kubernetes_version" {
  description = "Bản minor của Kubernetes. Chỉ ghi minor để AKS tự chọn bản vá mới nhất lúc tạo."
  type        = string
  # 1.35: GA, còn hỗ trợ cộng đồng (az aks get-versions 12/10); 1.37 còn preview.
  default = "1.35"
}

variable "node_vm_size" {
  description = "Size node của pool system (pool duy nhất)."
  type        = string
  # 2 vCPU / 8 GB. B-series rẻ hơn nhưng AKS không cho làm system pool
  # (learn.microsoft.com/azure/aks/quotas-skus-regions). 2 node = trọn quota 4 vCPU.
  default = "Standard_D2as_v5"
}

variable "node_min_count" {
  description = "Số node tối thiểu của cluster autoscaler."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Số node tối đa của cluster autoscaler."
  type        = number
  default     = 2

  validation {
    # Luật project (CLAUDE.md): autoscale tối đa 2 instance.
    condition     = var.node_max_count <= 2
    error_message = "node_max_count không được lớn hơn 2 (luật project: autoscale tối đa 2 instance)."
  }
}

variable "operator_object_id" {
  description = "Object ID của người vận hành: được cấp quyền kubectl (Azure RBAC) trên cluster."
  type        = string
  # Pin cứng, KHÔNG dùng data.azurerm_client_config.current.object_id — cùng lý do với
  # var.secrets_writer_object_id của infra/app (CI chạy plan bằng id-gh-plan sẽ thấy
  # principal đổi và đòi replace role assignment).
  default = "42330cda-5378-4f7e-bf4b-608ab2e632ec" # BUI TUNG LAM (az ad signed-in-user show)
}

variable "allowed_ips" {
  description = "IP được vào `fe` (Service LoadBalancer) và API server. Khoá = tên luật, giá trị = CIDR IPv4. Giá trị cá nhân — khai trong infra/aks/terraform.tfvars (KHÔNG commit)."
  type        = map(string)
  # Rỗng = KHOÁ API server với mọi IP (cluster.tf ép về 0.0.0.0/32), cùng hướng an toàn
  # với infra/app; gỡ bằng cách apply lại có tfvars (ARM vẫn vào được). Với Service
  # LoadBalancer của `fe` thì danh sách rỗng lại là MỞ ra Internet — nên
  # scripts/aks-render.sh từ chối render khi rỗng, và `make aks-up` từ chối chạy khi
  # chưa có terraform.tfvars. CI chạy plan không có tfvars nên luôn thấy rỗng → plan của
  # CI báo đổi authorized_ip_ranges khi cluster đang bật: diff giả đã biết, cùng loại
  # với ip_restriction của infra/app.
  default = {}
}

variable "db_name" {
  description = "Database RIÊNG của bản chạy trên AKS, tạo trên MySQL server của infra/app."
  type        = string
  # Không dùng chung `appdb` của App Service: test tải, /boom, drill trên AKS không được
  # ghi vào dữ liệu của môi trường demo.
  default = "appdb_aks"
}

# Hai công tắc chứng minh ngược, cùng cách dùng với grant_app_* của infra/app: luôn
# true trong code, đặt false bằng `-var` đúng một lần đo, rồi apply lại không có `-var`.

variable "grant_aks_keyvault_access" {
  description = "Gán Key Vault Secrets User cho identity của be/fe trên AKS. Đặt false CHỈ khi đo M5 (pod không mount được secret)."
  type        = bool
  default     = true
}

variable "grant_aks_acr_pull" {
  description = "Gán AcrPull cho kubelet identity. Đặt false CHỈ khi đo chứng minh ngược của M1 (pod ImagePullBackOff)."
  type        = bool
  default     = true
}

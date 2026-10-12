# Cluster AKS — một node pool, tier Free (control plane $0, không SLA: đủ cho bài học).
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  tags                = local.tags

  # Tên RG chứa VMSS / load balancer / public IP do AKS tự quản. Đặt tên rõ thay vì
  # mặc định MC_<rg>_<cluster>_<region> để `make aks-check-empty` và Cost analysis dễ đọc.
  node_resource_group = "rg-${var.project}-aks-nodes"

  # Quota chỉ có 4 vCPU = đúng 2 node: KHÔNG còn chỗ cho node "surge" mà mọi kiểu
  # nâng cấp đều cần. Tắt cả hai kênh tự nâng cấp để cluster không tự kẹt giữa chừng
  # (known-issues.md). Cluster này sống vài ngày, nâng cấp = destroy rồi apply.
  # automatic_upgrade_channel: KHÔNG khai = "none" (provider không nhận chuỗi "none",
  # chỉ nhận patch/rapid/stable/node-image — ai-failure-log.md).
  node_os_upgrade_channel = "None"

  # ---------- Ai được nói chuyện với API server (tương đương Kudu/SCM của M6) ----------
  # Tắt tài khoản local: không còn kubeconfig "admin" chứa chứng chỉ tĩnh. Mọi lệnh
  # kubectl phải có token Entra, và quyền trong cluster do Azure RBAC quyết định
  # (role assignment ở dưới + deploy-permissions.tf) — một hệ quyền duy nhất, thu hồi
  # được, có nhật ký.
  local_account_disabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Bài học D13: khoá site chính mà quên Kudu thì coi như chưa khoá. Ở AKS bề mặt quản
  # trị là API server. AKS tự cộng IP outbound của chính cluster vào danh sách này.
  # CD không nằm trong danh sách: nó chạy kubectl qua `az aks command invoke`, đi đường
  # ARM chứ không gọi thẳng API server (.github/workflows/cd-aks.yml).
  #
  # Danh sách rỗng với AKS nghĩa là KHÔNG GIỚI HẠN — ngược với App Service. Ép về
  # 0.0.0.0/32 (không IP nào khớp, chỉ còn IP outbound của cluster) để quên tfvars thì
  # KHOÁ chứ không MỞ, giống hành vi "map rỗng + Deny" của infra/app.
  api_server_access_profile {
    authorized_ip_ranges = length(local.allowed_cidrs) > 0 ? local.allowed_cidrs : ["0.0.0.0/32"]
  }

  identity {
    type = "SystemAssigned"
  }

  # ---------- Workload Identity + Key Vault CSI (tương đương M4/M5) ----------
  # OIDC issuer: cluster ký token cho service account; Entra tin token đó qua federated
  # credential (identity.tf) — cùng cơ chế GitHub OIDC của infra/bootstrap, không secret.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Add-on do AKS quản: driver CSI + provider Azure Key Vault. Không bật rotation:
  # app chỉ đọc secret lúc khởi động (Config.cs), xoay vòng = rollout lại.
  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  default_node_pool {
    name    = "system"
    vm_size = var.node_vm_size

    # Cluster autoscaler: 1 → 2 node (luật project: tối đa 2 instance).
    auto_scaling_enabled = true
    min_count            = var.node_min_count
    max_count            = var.node_max_count

    # 32 GB thay vì mặc định 128 GB: image của app ~200 MB, đĩa P4 rẻ hơn P10.
    os_disk_size_gb = 32

    # Pool duy nhất nên chạy cả pod hệ thống lẫn app (không taint CriticalAddonsOnly).
    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    # Azure CNI Overlay: pod lấy IP từ dải riêng (không ăn IP của subnet), dataplane
    # Cilium để NetworkPolicy có hiệu lực thật (k8s/base/networkpolicy.yaml) — thiếu
    # policy engine thì NetworkPolicy được nhận nhưng KHÔNG chặn gì.
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"

    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"

    # ĐÚNG MỘT IP outbound: firewall MySQL (db.tf) chỉ cần một rule. So với App Service
    # (20 "possible outbound IP" dùng chung cả stamp, phải apply nhiều pha) thì IP này
    # là của riêng cluster.
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  # Container Insights → workspace RIÊNG của AKS (monitoring.tf). Xác thực bằng managed
  # identity; thu gì là do data collection rule ở monitoring.tf quyết định.
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks.id
    msi_auth_for_monitoring_enabled = true
  }

  lifecycle {
    # Autoscaler sở hữu số node lúc chạy — cùng lý do `ignore_changes = [worker_count]`
    # của App Service Plan (infra/app/app.tf, quyết định A của D19).
    ignore_changes = [default_node_pool[0].node_count]
  }
}

# Quyền kubectl cho người vận hành. Owner ở subscription là control plane, KHÔNG gồm
# data action của Kubernetes (bài học D1: control plane ≠ data plane).
resource "azurerm_role_assignment" "operator_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.operator_object_id
}

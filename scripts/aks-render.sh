#!/usr/bin/env bash
# AKS (phần advanced) — ghép k8s/base với giá trị riêng môi trường rồi in manifest hoàn
# chỉnh ra stdout. Giá trị lấy từ `terraform -chdir=infra/aks output`: client id, tenant,
# tên Key Vault, host MySQL, IP whitelist — KHÔNG có thứ nào nằm trong git.
#
# CHỈ ĐỌC: không gọi `kubectl apply`, không đổi gì trên Azure. Cần `terraform init` sẵn
# cho infra/aks (make aks-init), `jq`, `kubectl`; cần `az login` khi phải tự tìm tag image.
#
# Dùng:
#   scripts/aks-render.sh [--tag SHA] | kubectl apply -f -
#
# Tag image, theo thứ tự ưu tiên:
#   1. --tag SHA
#   2. tag ĐANG CHẠY của từng Deployment trên cluster — apply lại cấu hình không được đảo
#      ngược bản mà cd-aks.yml đã deploy (cùng vai trò `ignore_changes` image ở infra/app)
#   3. cluster chưa có Deployment: tag mới nhất của vsf-be trong ACR

set -euo pipefail
export LC_ALL=C

TAG=""

usage() {
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--tag)
		TAG="$2"
		shift 2
		;;
	-h | --help) usage 0 ;;
	*)
		echo "!! tham số lạ: $1" >&2
		usage 2
		;;
	esac
done

cd "$(dirname "$0")/.."

OUTPUTS="$(terraform -chdir=infra/aks output -json)"
out() { jq -er --arg k "$1" '.[$k].value' <<<"$OUTPUTS"; }

NAMESPACE="$(out k8s_namespace)"
ACR="$(out acr_login_server)"
ACR_NAME="${ACR%%.*}"

# Danh sách rỗng ở Service LoadBalancer nghĩa là MỞ ra Internet (infra/aks/variables.tf).
CIDRS_JSON="$(jq -c '.allowed_cidrs.value' <<<"$OUTPUTS")"
if [[ "$(jq 'length' <<<"$CIDRS_JSON")" -eq 0 ]]; then
	echo "!! allowed_ips rỗng — render sẽ mở fe ra Internet. Khai infra/aks/terraform.tfvars rồi apply lại." >&2
	exit 1
fi

# Tag đang chạy của một Deployment; rỗng nếu cluster/Deployment chưa có.
running_tag() {
	local image
	image="$(kubectl -n "$NAMESPACE" get deployment "$1" \
		-o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
	[[ "$image" == "$ACR/"*:* ]] && printf '%s' "${image##*:}"
	return 0
}

BE_TAG="$TAG"
FE_TAG="$TAG"
[[ -z "$BE_TAG" ]] && BE_TAG="$(running_tag be)"
[[ -z "$FE_TAG" ]] && FE_TAG="$(running_tag fe)"
if [[ -z "$BE_TAG" || -z "$FE_TAG" ]]; then
	LATEST="$(az acr repository show-tags --name "$ACR_NAME" --repository vsf-be \
		--orderby time_desc --top 1 --query '[0]' -o tsv)"
	if [[ -z "$LATEST" ]]; then
		echo "!! ACR $ACR_NAME chưa có image vsf-be nào — chạy CD của App Service trước, hoặc truyền --tag." >&2
		exit 1
	fi
	BE_TAG="${BE_TAG:-$LATEST}"
	FE_TAG="${FE_TAG:-$LATEST}"
fi
echo ">> image: vsf-be:$BE_TAG  vsf-fe:$FE_TAG" >&2

OVERLAY="$(mktemp -d)"
trap 'rm -rf "$OVERLAY"' EXIT
BASE_REL="$(realpath --relative-to="$OVERLAY" k8s/base)"

# jq dựng file JSON (YAML nhận JSON): không phải tự escape giá trị nào.
jq -n \
	--arg base "$BASE_REL" --arg acr "$ACR" --arg be_tag "$BE_TAG" --arg fe_tag "$FE_TAG" \
	--arg tenant "$(out tenant_id)" --arg kv "$(out key_vault_name)" \
	--arg be_client "$(out be_identity_client_id)" --arg fe_client "$(out fe_identity_client_id)" \
	--arg db_host "$(out mysql_fqdn)" --arg db_name "$(out mysql_database_name)" \
	--arg db_user "$(out mysql_admin_login)" --argjson cidrs "$CIDRS_JSON" '
	def spc($client): [
		{op: "replace", path: "/spec/parameters/clientID", value: $client},
		{op: "replace", path: "/spec/parameters/keyvaultName", value: $kv},
		{op: "replace", path: "/spec/parameters/tenantId", value: $tenant}
	] | tojson;
	{
		apiVersion: "kustomize.config.k8s.io/v1beta1",
		kind: "Kustomization",
		resources: [$base],
		images: [
			{name: "vsf-be", newName: ($acr + "/vsf-be"), newTag: $be_tag},
			{name: "vsf-fe", newName: ($acr + "/vsf-fe"), newTag: $fe_tag}
		],
		patches: [
			{target: {kind: "SecretProviderClass", name: "be-secrets"}, patch: spc($be_client)},
			{target: {kind: "SecretProviderClass", name: "fe-secrets"}, patch: spc($fe_client)},
			{target: {kind: "ConfigMap", name: "be-config"}, patch: ([
				{op: "replace", path: "/data/DB_HOST", value: $db_host},
				{op: "replace", path: "/data/DB_NAME", value: $db_name},
				{op: "replace", path: "/data/DB_USER", value: $db_user}
			] | tojson)},
			{target: {kind: "Service", name: "fe"}, patch: ([
				{op: "replace", path: "/spec/loadBalancerSourceRanges", value: $cidrs}
			] | tojson)}
		]
	}' >"$OVERLAY/kustomization.yaml"

kubectl kustomize "$OVERLAY"

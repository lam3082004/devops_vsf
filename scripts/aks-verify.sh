#!/usr/bin/env bash
# AKS (phần advanced) — bảng kiểm sau `make aks-up`, CHỈ ĐỌC. Mỗi dòng một phép kiểm:
# OK / WARN / FAIL. Exit 1 nếu có FAIL. Cùng kiểu với scripts/demo-preflight.sh.
#
# Chỉ gửi GET tới `fe` qua load balancer + lệnh đọc của `kubectl`/`az`/`terraform output`
# — không đổi gì, không phát sinh chi phí. Không in đủ IP. Máy chạy phải `az login`, đã
# `make aks-credentials`, và nằm trong whitelist (nếu không: các dòng HTTP báo FAIL).
#
# Dùng:
#   scripts/aks-verify.sh [--out FILE]

set -uo pipefail
export LC_ALL=C

OUT=""

usage() {
	sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--out)
		OUT="$2"
		shift 2
		;;
	-h | --help) usage 0 ;;
	*)
		echo "!! tham số lạ: $1" >&2
		usage 2
		;;
	esac
done

cd "$(dirname "$0")/.." || exit 2
if [[ -n "$OUT" ]]; then
	mkdir -p "$(dirname "$OUT")"
	exec > >(tee "$OUT") 2>&1
fi

FAILS=0
WARNS=0
ok() { printf 'OK    %s\n' "$*"; }
warn() {
	printf 'WARN  %s\n' "$*"
	WARNS=$((WARNS + 1))
}
fail() {
	printf 'FAIL  %s\n' "$*"
	FAILS=$((FAILS + 1))
}
# Che 2 octet cuối: bằng chứng dán vào repo không được chứa đủ IP.
mask() { sed -E 's/([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/\1.x.x/g'; }

OUTPUTS="$(terraform -chdir=infra/aks output -json 2>/dev/null)"
if [[ -z "$OUTPUTS" || "$OUTPUTS" == "{}" ]]; then
	echo "!! infra/aks chưa có output — chạy make aks-up trước" >&2
	exit 2
fi
out() { jq -r --arg k "$1" '.[$k].value' <<<"$OUTPUTS"; }

RG="$(out resource_group_name)"
CLUSTER="$(out cluster_name)"
NS="$(out k8s_namespace)"
ACR="$(out acr_login_server)"
BASE_RG="rg-vsf-dev"
MYSQL="$(out mysql_fqdn)"
MYSQL="${MYSQL%%.*}"
K="kubectl -n $NS"

echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ) aks-verify cluster=$CLUSTER suffix=$(out name_suffix)"

# ---------- cluster ----------
SHOW="$(az aks show -g "$RG" -n "$CLUSTER" -o json 2>/dev/null)"
if [[ -z "$SHOW" ]]; then
	fail "không đọc được cluster $CLUSTER"
	echo "# kết quả: $FAILS FAIL, $WARNS WARN"
	exit 1
fi
q() { jq -r "$1" <<<"$SHOW"; }

if [[ "$(q .provisioningState)" == "Succeeded" ]]; then
	ok "cluster Succeeded, Kubernetes $(q .currentKubernetesVersion), tier $(q .sku.tier)"
else
	fail "provisioningState = $(q .provisioningState)"
fi
if [[ "$(q .disableLocalAccounts)" == "true" ]]; then
	ok "tài khoản local đã tắt (chỉ Entra)"
else
	fail "tài khoản local còn bật"
fi
if [[ "$(q .aadProfile.enableAzureRbac)" == "true" ]]; then
	ok "Azure RBAC cho Kubernetes bật"
else
	fail "Azure RBAC chưa bật"
fi
RANGES="$(q '.apiServerAccessProfile.authorizedIpRanges | length')"
if [[ "$RANGES" -gt 0 ]]; then
	ok "API server giới hạn $RANGES dải IP"
else
	fail "API server KHÔNG giới hạn IP"
fi
MAXN="$(q '.agentPoolProfiles[0].maxCount // empty')"
# maxCount rỗng = autoscaler tắt: `[[ "" -le 2 ]]` sẽ đúng oan, phải kiểm riêng.
if [[ "$MAXN" =~ ^[0-9]+$ && "$MAXN" -le 2 ]]; then
	ok "cluster autoscaler $(q '.agentPoolProfiles[0].minCount')–$MAXN node, đang $(q '.agentPoolProfiles[0].count')"
else
	fail "cluster autoscaler: maxCount = '${MAXN:-không có}' (phải bật và ≤ 2 — luật project)"
fi
if [[ "$(q .networkProfile.networkPolicy)" == "cilium" ]]; then
	ok "network policy engine = cilium"
else
	fail "networkPolicy = $(q .networkProfile.networkPolicy) — NetworkPolicy sẽ không chặn gì"
fi

NOT_READY="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready"' | wc -l)"
NODES="$(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
if [[ "$NODES" -ge 1 && "$NOT_READY" -eq 0 ]]; then
	ok "$NODES node Ready"
else
	fail "node: $NODES tổng, $NOT_READY chưa Ready"
fi

# ---------- M1: pull bằng managed identity ----------
if [[ "$(az acr show -n "${ACR%%.*}" --query adminUserEnabled -o tsv 2>/dev/null)" == "false" ]]; then
	ok "ACR admin user = disabled"
else
	fail "ACR admin user không phải disabled"
fi
for d in be fe; do
	IMG="$($K get deploy "$d" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
	PULLSEC="$($K get deploy "$d" -o jsonpath='{.spec.template.spec.imagePullSecrets}' 2>/dev/null)"
	READY="$($K get deploy "$d" -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null)"
	if [[ "$IMG" == "$ACR/"* && -z "$PULLSEC" ]]; then
		ok "$d: image từ ACR (tag ${IMG##*:}), không imagePullSecrets, ready $READY"
	else
		fail "$d: image=$IMG imagePullSecrets=$PULLSEC"
	fi
	[[ "${READY%%/*}" -ge 1 ]] 2>/dev/null || fail "$d: chưa có pod Ready ($READY)"
done

# ---------- M4: không secret viết tay ----------
# `kubectl` lỗi (mất quyền, không tới được API server) không được thành "0 secret viết tay".
if SECRETS="$($K get secrets -o json 2>/dev/null)"; then
	TOTAL="$(jq '.items | length' <<<"$SECRETS")"
	HAND="$(jq -r '[.items[] | select(.metadata.labels["secrets-store.csi.k8s.io/managed"] != "true") | .metadata.name] | join(",")' <<<"$SECRETS")"
	if [[ "$TOTAL" -ge 2 && -z "$HAND" ]]; then
		ok "$TOTAL Secret trong $NS, tất cả do driver CSI đồng bộ từ Key Vault"
	else
		fail "Secret trong $NS: $TOTAL tổng (cần ≥ 2), không do CSI quản: ${HAND:-không}"
	fi
else
	fail "không đọc được Secret trong $NS (kubectl lỗi)"
fi

# ---------- M3: MySQL ----------
RULE_IP="$(az mysql flexible-server firewall-rule show -g "$BASE_RG" -n "$MYSQL" -r aks-outbound --query startIpAddress -o tsv 2>/dev/null)"
if [[ -n "$RULE_IP" && "$RULE_IP" == "$(out aks_outbound_ip)" ]]; then
	ok "firewall MySQL aks-outbound = IP outbound của cluster ($(mask <<<"$RULE_IP"))"
else
	fail "firewall MySQL aks-outbound lệch IP outbound"
fi

# ---------- M6 + app qua load balancer ----------
LB="$($K get svc fe -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"
# Phải khớp ĐÚNG danh sách của Terraform: "có ít nhất một dải" vẫn đúng với dải giữ chỗ
# 192.0.2.1/32 của k8s/base (không ai vào được) hay 0.0.0.0/0 (ai cũng vào được).
SRC="$($K get svc fe -o json 2>/dev/null | jq -c '.spec.loadBalancerSourceRanges // [] | sort')"
WANT="$(jq -c '.allowed_cidrs.value | sort' <<<"$OUTPUTS")"
if [[ -n "$SRC" && "$SRC" == "$WANT" && "$(jq 'length' <<<"$SRC")" -gt 0 ]]; then
	ok "Service fe giới hạn $(jq 'length' <<<"$SRC") dải IP, khớp allowed_ips của infra/aks"
else
	fail "loadBalancerSourceRanges của Service fe KHÔNG khớp allowed_ips của infra/aks ($(jq 'length' <<<"${SRC:-[]}") dải)"
fi
if [[ "$($K get svc be -o jsonpath='{.spec.type}' 2>/dev/null)" == "ClusterIP" ]]; then
	ok "be là ClusterIP (không có IP công khai)"
else
	fail "be không phải ClusterIP"
fi
if [[ -n "$($K get networkpolicy be-ingress -o name 2>/dev/null)" ]]; then
	ok "NetworkPolicy be-ingress tồn tại (phép thử chặn thật: evidence/advanced/aks-m6.md)"
else
	fail "thiếu NetworkPolicy be-ingress"
fi

if [[ -z "$LB" ]]; then
	fail "Service fe chưa có IP công khai"
else
	get() { curl -4 -s -o "$2" -w '%{http_code}' --max-time 8 --retry 2 "http://$LB$1" 2>/dev/null; }
	TMP="$(mktemp)"
	CODE="$(get /api/version "$TMP")"
	FE_SHA="$(jq -r '.sha // empty' "$TMP" 2>/dev/null)"
	FE_TAG="$($K get deploy fe -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
	if [[ "$CODE" == "200" && -n "$FE_SHA" && "${FE_TAG##*:}" == "$FE_SHA"* ]]; then
		ok "fe /api/version = 200, SHA ${FE_SHA:0:7} khớp tag image (LB $(mask <<<"$LB"))"
	else
		fail "fe /api/version = $CODE sha=${FE_SHA:0:7} tag=${FE_TAG##*:}"
	fi
	CODE="$(get /api/health "$TMP")"
	if [[ "$CODE" == "200" ]]; then
		ok "fe /api/health = 200 (fe → be → MySQL thông)"
	else
		fail "fe /api/health = $CODE: $(head -c 200 "$TMP")"
	fi
	# Như smoke test của cd.yml: trang chủ render phía server, mỗi lần đều gọi `be`.
	CODE="$(get / "$TMP")"
	if [[ "$CODE" == "200" ]]; then
		ok "fe GET / = 200 (trang board, dữ liệu từ $(out mysql_database_name))"
	else
		fail "fe GET / = $CODE"
	fi
	rm -f "$TMP"
fi

# ---------- M7 + sẵn sàng khi gỡ node ----------
HPA_MAX="$($K get hpa be -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)"
if [[ "$HPA_MAX" == "2" ]]; then
	ok "HPA be: $($K get hpa be -o jsonpath='{.spec.minReplicas}')–$HPA_MAX pod, đang $($K get hpa be -o jsonpath='{.status.currentReplicas}')"
else
	fail "HPA be maxReplicas = ${HPA_MAX:-không có}"
fi
# PDB chỉ bảo vệ khi còn bản để nhường: cần ≥ 2 bản Ready VÀ được phép mất ≥ 1.
for d in be fe; do
	READY_N="$($K get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
	ALLOWED="$($K get pdb "$d" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)"
	if [[ "${READY_N:-0}" -ge 2 && "${ALLOWED:-0}" -ge 1 ]]; then
		ok "$d: $READY_N bản Ready, PodDisruptionBudget cho phép mất $ALLOWED (gỡ node không lấy mất bản cuối)"
	else
		fail "$d: ${READY_N:-0} bản Ready, PDB disruptionsAllowed = ${ALLOWED:-không có PDB}"
	fi
done

echo "# kết quả: $FAILS FAIL, $WARNS WARN"
[[ "$FAILS" -eq 0 ]]

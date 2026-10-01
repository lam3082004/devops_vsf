#!/usr/bin/env bash
# D23 — chứng minh ngược quyền của id-agent-triage (evidence/agent.md). Mỗi phép thử
# có một kết quả mong đợi:
#   ok     → lệnh phải THÀNH CÔNG (việc agent được phép làm)
#   <mẫu>  → lệnh phải THẤT BẠI và stderr khớp mẫu (đúng loại lỗi quyền)
# Script đỏ (exit 1) nếu một phép bị cấm lại THÀNH CÔNG, hoặc thất bại sai loại (ví dụ
# lỗi mạng thay vì lỗi RBAC): "thất bại" vì lý do khác không chứng minh được gì.
#
# Chạy trong .github/workflows/agent-triage.yml (mode=prove) sau `azure/login`.
# KHÔNG chạy bằng `az login` của mình: Owner sẽ làm mọi phép bị cấm THÀNH CÔNG thật
# (restart slot staging, tạo RG, tự gán Owner) — script tự chặn nếu danh tính là user.
#
# stdout của mọi lệnh bị nuốt (không in): nếu quyền lỡ rộng hơn thiết kế thì giá trị
# secret / shared key cũng không lọt vào log. Chỉ stderr (lỗi nguyên văn) được in.
#
# Dùng:
#   scripts/agent-prove.sh [--rg rg-vsf-dev] [--out FILE]

set -uo pipefail
export LC_ALL=C

RG="rg-vsf-dev"
OUT=""

usage() {
	sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--rg)
		RG="$2"
		shift 2
		;;
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

acct=$(az account show -o json) || {
	echo "!! chưa đăng nhập Azure" >&2
	exit 1
}
if [[ $(jq -r .user.type <<<"$acct") != "servicePrincipal" ]]; then
	echo "!! danh tính hiện tại là user ($(jq -r .user.name <<<"$acct")) — chỉ chạy bằng id-agent-triage (workflow agent-triage.yml)" >&2
	exit 2
fi
SUB=$(jq -r .id <<<"$acct")
CLIENT_ID=$(jq -r .user.name <<<"$acct")
# Object id của chính mình lấy từ claim `oid` của token ARM: agent không có quyền đọc
# Microsoft Graph để tra `az ad sp show`.
OID=$(az account get-access-token --query accessToken -o tsv | cut -d. -f2 | tr '_-' '/+' |
	awk '{ n = length($0) % 4; if (n) $0 = $0 substr("===", 1, 4 - n); print }' | base64 -d 2>/dev/null | jq -r .oid)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
[[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")" && : >"$OUT"
emit() {
	if [[ -n "$OUT" ]]; then cat >>"$OUT"; else cat; fi
}

# Tên resource suy ra từ workspace (Resource Graph chỉ trả thứ agent đọc được): log-vsf-<suffix>.
jq -n --arg s "$SUB" --arg q "resources | where type =~ 'microsoft.operationalinsights/workspaces' and resourceGroup =~ '$RG' | project name, id" \
	'{subscriptions: [$s], query: $q}' >"$TMP/graph.json"
ws=$(az rest --method post --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
	--body "@$TMP/graph.json" --query "data[0]" -o json) || exit 1
WS_ID=$(jq -r '.id // empty' <<<"$ws")
SUFFIX=$(jq -r '.name // empty' <<<"$ws" | sed 's/^log-vsf-//')
if [[ -z "$WS_ID" || -z "$SUFFIX" ]]; then
	echo "!! không thấy workspace trong $RG — môi trường tắt?" >&2
	exit 1
fi
RG_ID="/subscriptions/$SUB/resourceGroups/$RG"
BE="app-vsf-$SUFFIX"
KV="kv-vsf-$SUFFIX"

fail=0
n=0
rows=()
details=()

# check <tên> <mong đợi: ok | regex lỗi> <lệnh...>
check() {
	local name="$1" expect="$2"
	shift 2
	n=$((n + 1))
	local rc verdict err
	"$@" >/dev/null 2>"$TMP/err"
	rc=$?
	# Che subscription id trong lỗi nguyên văn; object/client id của agent giữ lại (đã
	# công khai trong evidence, không phải secret).
	err=$(sed "s/$SUB/<sub>/g" "$TMP/err" | tr -s '\n' ' ' | cut -c1-600)
	if [[ "$expect" == "ok" ]]; then
		if ((rc == 0)); then verdict="đạt (thành công)"; else
			verdict="**LỆCH**: lẽ ra thành công"
			fail=1
		fi
	elif ((rc == 0)); then
		verdict="**VƯỢT QUYỀN**: lẽ ra bị chặn"
		fail=1
	elif grep -Eq "$expect" <<<"$err"; then
		verdict="đạt (bị chặn đúng loại)"
	else
		verdict="**LỆCH**: thất bại sai loại (mong \`$expect\`)"
		fail=1
	fi
	echo "[$n] $name → rc=$rc · $verdict" >&2
	rows+=("| $n | $name | \`$expect\` | $rc | $verdict |")
	details+=("**[$n] $name** · \`$(printf '%q ' "$@" | sed "s/$SUB/<sub>/g" | cut -c1-200)\`" "" '```' "${err:-(stderr rỗng)}" '```' "")
}

# --- việc được phép ---
jq -n '{query: "AppServiceHTTPLogs | summarize n = count()", timespan: "PT24H"}' >"$TMP/kql.json"
WS_CID=$(az rest --method post --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
	--body "$(jq -n --arg s "$SUB" --arg q "resources | where id =~ '$WS_ID' | project c = tostring(properties.customerId)" '{subscriptions: [$s], query: $q}')" \
	--query "data[0].c" -o tsv)
check "KQL trên workspace (Log Analytics Reader)" ok \
	az rest --method post --url "https://api.loganalytics.io/v1/workspaces/$WS_CID/query" \
	--resource "https://api.loganalytics.io" --body "@$TMP/kql.json"
jq -n --arg s "$SUB" --arg q "alertsmanagementresources | where tostring(properties.essentials.targetResourceGroup) =~ '$RG' | count" \
	'{subscriptions: [$s], query: $q}' >"$TMP/alerts.json"
check "đọc alert qua Resource Graph (vsf-agent-alert-reader)" ok \
	az rest --method post --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
	--body "@$TMP/alerts.json"

# --- việc bị cấm ---
check "đọc secret Key Vault (data plane)" "Forbidden" \
	az keyvault secret show --vault-name "$KV" -n mysql-admin-password --query id -o tsv
check "lấy shared key của workspace (notAction của Log Analytics Reader)" "AuthorizationFailed" \
	az rest --method post --url "https://management.azure.com$WS_ID/sharedKeys?api-version=2020-08-01"
check "đọc cấu hình Web App be (ip_restriction = IP cá nhân)" "AuthorizationFailed" \
	az rest --method get --url "https://management.azure.com$RG_ID/providers/Microsoft.Web/sites/$BE/config/web?api-version=2023-12-01"
check "liệt kê app settings be (config/list/action)" "AuthorizationFailed" \
	az rest --method post --url "https://management.azure.com$RG_ID/providers/Microsoft.Web/sites/$BE/config/appsettings/list?api-version=2023-12-01"
# Slot staging thay vì production: nếu quyền lỡ rộng, hậu quả là restart staging, không
# phải gián đoạn người dùng.
check "restart Web App be (slot staging)" "AuthorizationFailed" \
	az rest --method post --url "https://management.azure.com$RG_ID/providers/Microsoft.Web/sites/$BE/slots/staging/restart?api-version=2023-12-01"
check "tạo resource group mới" "AuthorizationFailed" \
	az group create -n rg-agent-should-fail -l southeastasia --tags purpose=d23-prove
check "tự gán Owner cho chính mình trên $RG" "AuthorizationFailed" \
	az role assignment create --assignee-object-id "$OID" --assignee-principal-type ServicePrincipal \
	--role Owner --scope "$RG_ID"

{
	echo "## Chứng minh ngược: id-agent-triage"
	echo
	echo "Chạy lúc $(date -u +%FT%TZ) · client id \`$CLIENT_ID\` · object id \`$OID\` · RG \`$RG\`"
	echo
	echo "| # | phép thử | mong đợi | rc | kết quả |"
	echo "|---|---|---|---|---|"
	printf '%s\n' "${rows[@]}"
	echo
	echo "### Lỗi nguyên văn (stderr, subscription id đã che)"
	echo
	printf '%s\n' "${details[@]}"
} | emit

[[ -n "$OUT" && -n "${GITHUB_STEP_SUMMARY:-}" ]] && cat "$OUT" >>"$GITHUB_STEP_SUMMARY"
if ((fail)); then
	echo "!! có phép thử LỆCH hoặc VƯỢT QUYỀN — xem bảng" >&2
fi
exit "$fail"

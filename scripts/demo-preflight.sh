#!/usr/bin/env bash
# D25 — kiểm tra T−60 phút trước demo (docs/guides/d25-demo.md mục 2), CHỈ ĐỌC. Kế hoạch:
# notes/d25-prep.md mục 2. Mỗi dòng một phép kiểm: OK / WARN / FAIL. Exit 1 nếu có FAIL.
#
# Chỉ gửi GET tới URL công khai + lệnh `az`/`gh` đọc (show/list/Resource Graph/KQL) — không
# đổi gì trên Azure hay GitHub, không phát sinh chi phí. Không in email, không in đủ IP.
# Máy chạy phải đăng nhập `az` + `gh`, và nằm trong whitelist (nếu không: mục IP báo FAIL).
#
# Dùng:
#   scripts/demo-preflight.sh --suffix jcip0s [--out FILE]
# --out: ghi thêm bản sao kết quả (mặc định chỉ in ra màn hình).

set -uo pipefail
export LC_ALL=C

SUFFIX=""
OUT=""
RG="rg-vsf-dev"

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
	--suffix)
		SUFFIX="$2"
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

if ! [[ "$SUFFIX" =~ ^[a-z0-9]{6}$ ]]; then
	echo "!! --suffix phải là 6 ký tự a-z0-9 (vd jcip0s)" >&2
	usage 2
fi
if [[ -n "$OUT" ]]; then
	mkdir -p "$(dirname "$OUT")"
	exec > >(tee "$OUT") 2>&1
fi

BE_APP="app-vsf-$SUFFIX"
FE_APP="fe-vsf-$SUFFIX"
BE="https://$BE_APP.azurewebsites.net"
FE="https://$FE_APP.azurewebsites.net"
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
get() { curl -4 -s --max-time 10 "$1" 2>/dev/null; }
code() { curl -4 -s -o /dev/null --max-time 10 -w '%{http_code}' "$1" 2>/dev/null || echo 000; }

echo "# $(date -u +%FT%TZ) demo-preflight suffix=$SUFFIX"

# 1. Subscription còn dùng được (Free Trial hết hạn 15/10 — Q5).
st=$(az account show --query state -o tsv 2>/dev/null)
if [[ "$st" == "Enabled" ]]; then ok "subscription state = Enabled"; else fail "subscription state = '${st:-không đọc được}' (az login? Free Trial hết hạn?)"; fi
SUB=$(az account show --query id -o tsv 2>/dev/null)

# 2. Production sống.
h=$(get "$BE/health")
if [[ "$(jq -r '.status + "/" + .db' <<<"$h" 2>/dev/null)" == "ok/ok" ]]; then ok "be /health = ok, db = ok"; else fail "be /health = '${h:0:80}' ($(code "$BE/health"))"; fi
c=$(code "$FE/api/health")
if [[ "$c" == 200 ]]; then ok "fe /api/health = 200"; else fail "fe /api/health = $c"; fi

# 3. Production chạy đúng SHA của main; staging giữ bản trước (đích của swap ngược).
main_sha=$(git ls-remote origin refs/heads/main 2>/dev/null | cut -c1-7)
be_sha=$(get "$BE/version" | jq -r '.sha // empty' 2>/dev/null | cut -c1-7)
fe_sha=$(get "$FE/api/version" | jq -r '.sha // empty' 2>/dev/null | cut -c1-7)
if [[ -n "$main_sha" && "$be_sha" == "$main_sha" && "$fe_sha" == "$main_sha" ]]; then
	ok "production be = fe = main = $main_sha"
else
	warn "SHA lệch: main=${main_sha:--} be=${be_sha:--} fe=${fe_sha:--} (CD đang chạy hoặc lỗi?)"
fi
bs=$(get "https://$BE_APP-staging.azurewebsites.net/version" | jq -r '.sha // empty' 2>/dev/null | cut -c1-7)
fs=$(get "https://$FE_APP-staging.azurewebsites.net/api/version" | jq -r '.sha // empty' 2>/dev/null | cut -c1-7)
if [[ -n "$bs" && -n "$fs" ]]; then
	ok "staging be=$bs fe=$fs (bản swap ngược sẽ đưa lên production)"
else
	warn "staging không đọc được SHA (be=${bs:--} fe=${fs:--}) — demo swap ngược sẽ đưa bản không rõ lên production"
fi

# 4. Whitelist 4 bề mặt × 2 app: Deny mặc định, scm dùng luật site chính, không còn luật tạm cd-*.
for app in "$BE_APP" "$FE_APP"; do
	for slot in "" staging; do
		label="$app${slot:+/$slot}"
		ar=$(az webapp config access-restriction show -g "$RG" -n "$app" ${slot:+--slot "$slot"} -o json 2>/dev/null)
		if [[ -z "$ar" ]]; then
			fail "$label: không đọc được access restriction"
			continue
		fi
		d=$(jq -r '.ipSecurityRestrictionsDefaultAction' <<<"$ar")
		m=$(jq -r '.scmIpSecurityRestrictionsUseMain' <<<"$ar")
		t=$(jq -r '[.ipSecurityRestrictions[].name | select(startswith("cd-"))] | length' <<<"$ar")
		if [[ "$d" == Deny && "$m" == true && "$t" == 0 ]]; then
			ok "$label: Unmatched = Deny, scm dùng luật chính, 0 luật cd-*"
		else
			fail "$label: default=$d scmUseMain=$m luật cd-*=$t"
		fi
	done
done

# 5. IP nơi demo nằm trong whitelist của be (bỏ luật fe-outbound-*). In IP đã che 2 octet cuối.
myip=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null)
mapfile -t cidrs < <(az webapp config access-restriction show -g "$RG" -n "$BE_APP" \
	--query "ipSecurityRestrictions[?action=='Allow' && !starts_with(name, 'fe-outbound-')].ipAddress" -o tsv 2>/dev/null)
masked=$(sed -E 's/\.[0-9]+\.[0-9]+$/.x.x/' <<<"$myip")
if [[ -z "$myip" ]]; then
	fail "không đọc được IP egress của máy"
elif python3 - "$myip" "${cidrs[@]}" <<'PY'; then
import ipaddress, sys
ip = ipaddress.ip_address(sys.argv[1])
sys.exit(0 if any(ip in ipaddress.ip_network(c, strict=False) for c in sys.argv[2:]) else 1)
PY
	ok "IP egress $masked nằm trong whitelist be"
else
	fail "IP egress $masked KHÔNG nằm trong whitelist be → sửa terraform.tfvars + apply (hỏi trước)"
fi

# 6. KV reference Resolved: be (DB_PASSWORD) site + staging, fe (App Insights) site.
kvref() {
	az rest --method get --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$1/config/configreferences/appsettings/$2?api-version=2022-03-01" \
		--query properties.status -o tsv 2>/dev/null
}
for ref in "$BE_APP DB_PASSWORD" "$BE_APP/slots/staging DB_PASSWORD" "$FE_APP APPLICATIONINSIGHTS_CONNECTION_STRING"; do
	read -r site name <<<"$ref"
	s=$(kvref "$site" "$name")
	if [[ "$s" == Resolved ]]; then ok "KV reference $site $name = Resolved"; else fail "KV reference $site $name = '${s:-không đọc được}'"; fi
done

# 7. ACR admin tắt (M1).
adm=$(az acr list -g "$RG" --query "[0].adminUserEnabled" -o tsv 2>/dev/null)
if [[ "$adm" == false ]]; then ok "ACR admin user = disabled"; else fail "ACR adminUserEnabled = '${adm:-?}'"; fi

# 8. Alert: 3 rule bật, action group có email, không alert nào đang Fired.
en=$(az resource list -g "$RG" --query "[?type=='Microsoft.Insights/metricalerts' || type=='Microsoft.Insights/scheduledqueryrules'].id" -o tsv 2>/dev/null |
	while read -r id; do az resource show --ids "$id" --query "[name, to_string(properties.enabled)]" -o tsv 2>/dev/null | paste -sd' '; done)
n_on=$(grep -c ' true$' <<<"$en")
if [[ "$n_on" -ge 3 ]]; then ok "alert rule bật: $n_on ($(cut -d' ' -f1 <<<"$en" | paste -sd, -))"; else fail "alert rule bật: $n_on/3 — $(paste -sd, - <<<"$en")"; fi
ne=$(az monitor action-group show -g "$RG" -n ag-vsf-oncall --query "length(emailReceivers)" -o tsv 2>/dev/null)
if [[ "${ne:-0}" -ge 1 ]]; then ok "action group ag-vsf-oncall có $ne email receiver"; else fail "action group không có email receiver (thiếu alert_email trong terraform.tfvars của checkout đã apply?)"; fi
KQ="alertsmanagementresources | where tostring(properties.essentials.targetResourceGroup) =~ '$RG'"
KQ+=" | where tostring(properties.essentials.monitorCondition) == 'Fired' | where tostring(properties.essentials.alertState) != 'Closed'"
KQ+=" | project n = tostring(properties.essentials.alertRule)"
Q=$(jq -n --arg s "$SUB" --arg q "$KQ" '{subscriptions: [$s], query: $q}')
fired=$(az rest --method post --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
	--body "$Q" --query "data[].n" -o tsv 2>/dev/null | sed 's#.*/##' | sort -u | paste -sd, -)
if [[ -z "$fired" ]]; then ok "không alert nào đang Fired"; else warn "alert đang Fired: $fired (đóng/đợi Resolved trước demo)"; fi

# 9. Autoscale max 2 (luật CLAUDE.md), plan đang 1 instance.
as=$(az monitor autoscale show -g "$RG" -n autoscale-vsf-dev --query "[to_string(enabled), profiles[0].capacity.maximum]" -o tsv 2>/dev/null | paste -sd' ')
cap=$(az appservice plan show -g "$RG" -n asp-vsf-dev --query sku.capacity -o tsv 2>/dev/null)
if [[ "$as" == "true 2" && "$cap" == 1 ]]; then ok "autoscale bật, max 2, plan đang $cap instance"; else warn "autoscale '$as', plan capacity '${cap:-?}' (chờ scale in xong trước phần /load)"; fi

# 10. Workbook có dữ liệu: AppServiceHTTPLogs 30 phút gần nhất.
ws=$(az monitor log-analytics workspace show -g "$RG" -n "log-vsf-$SUFFIX" --query customerId -o tsv 2>/dev/null)
n=$(az rest --method post --url "https://api.loganalytics.io/v1/workspaces/$ws/query" --resource https://api.loganalytics.io \
	--body '{"query":"AppServiceHTTPLogs | where TimeGenerated > ago(30m) | count"}' --query "tables[0].rows[0][0]" -o tsv 2>/dev/null)
if [[ "${n:-0}" -gt 0 ]]; then ok "workspace có $n dòng AppServiceHTTPLogs trong 30 phút"; else warn "workspace chưa có log HTTP 30 phút qua — gọi vài request rồi đợi 2–5 phút"; fi

# 11. CD gần nhất trên main xanh, đúng SHA main.
cd=$(gh run list --workflow cd.yml --branch main --limit 1 --json conclusion,headSha,databaseId -q '.[0] | "\(.conclusion) \(.headSha[0:7]) \(.databaseId)"' 2>/dev/null)
read -r cdc cds cdi <<<"$cd"
if [[ "$cdc" == success && "$cds" == "$main_sha" ]]; then ok "CD cuối trên main: success ($cds, run $cdi)"; else warn "CD cuối trên main: ${cd:-không đọc được} (main=$main_sha)"; fi

# 12. Hạn ngoại lệ Trivy (cổng CD tự đỏ lại khi hết hạn).
exp=$(grep -oE 'exp:[0-9]{4}-[0-9]{2}-[0-9]{2}' .trivyignore 2>/dev/null | sort | head -1 | cut -d: -f2)
if [[ -n "$exp" ]]; then
	left=$((($(date -u -d "$exp" +%s) - $(date -u +%s)) / 86400))
	if ((left < 0)); then
		fail ".trivyignore hết hạn $exp — mọi PR/CD sẽ đỏ ở cổng Trivy"
	elif ((left < 3)); then
		warn ".trivyignore còn $left ngày (hết hạn $exp)"
	else
		ok ".trivyignore còn $left ngày (hết hạn $exp)"
	fi
fi

# 13. Thông tin (không tính điểm): PR đang mở, web app lạ trên plan (PoC — known-issues #23).
echo "INFO  PR đang mở: $(gh pr list --state open --json number -q 'map("#\(.number)") | join(" ")' 2>/dev/null)"
other=$(az webapp list -g "$RG" --query "[?!(starts_with(name, 'app-vsf-') || starts_with(name, 'fe-vsf-'))].name" -o tsv 2>/dev/null | paste -sd, -)
echo "INFO  web app khác trên $RG: ${other:-không có} (PoC → make down sẽ gãy, #23)"

echo "# kết quả: $FAILS FAIL, $WARNS WARN"
((FAILS == 0))

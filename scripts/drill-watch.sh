#!/usr/bin/env bash
# D24 — watcher CHỈ ĐỌC cho incident drill (notes/d24-prep.md Pha C). Mỗi INTERVAL giây ghi một
# dòng TSV: mã HTTP của be /health, be /items, fe /api/health, SHA đang chạy ở be production, và
# trạng thái alert `alert-vsf-5xx-rate` mới nhất (Resource Graph). File TSV là timeline của drill.
#
# Không gây tải đáng kể (3 request / INTERVAL) và không đổi gì trên Azure. Máy chạy phải nằm trong
# whitelist (M6), nếu không mọi mã là 403.
#
# Dùng:
#   scripts/drill-watch.sh --suffix jcip0s [--interval 30] [--duration 3600] [--out FILE]
# Dừng sớm: Ctrl+C.

set -uo pipefail
export LC_ALL=C

SUFFIX=""
INTERVAL=30
DURATION=3600
OUT="evidence/raw/d24-drill-watch-$(date -u +%Y%m%d-%H%M%S).tsv"
RG="rg-vsf-dev"

usage() {
	sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
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
	--interval)
		INTERVAL="$2"
		shift 2
		;;
	--duration)
		DURATION="$2"
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

if [[ -z "$SUFFIX" ]]; then
	echo "!! thiếu --suffix" >&2
	usage 2
fi
if ! [[ "$INTERVAL" =~ ^[0-9]+$ && "$DURATION" =~ ^[0-9]+$ ]] || ((INTERVAL < 10 || DURATION > 7200)); then
	echo "!! --interval ≥ 10, --duration ≤ 7200 giây" >&2
	exit 2
fi

BE="https://app-vsf-$SUFFIX.azurewebsites.net"
FE="https://fe-vsf-$SUFFIX.azurewebsites.net"
SUB=$(az account show --query id -o tsv) || exit 1
KQ="alertsmanagementresources | where tostring(properties.essentials.targetResourceGroup) =~ '$RG'"
KQ+=" | where tostring(properties.essentials.alertRule) has '5xx-rate'"
KQ+=" | top 1 by todatetime(properties.essentials.startDateTime) desc"
KQ+=" | project c = tostring(properties.essentials.monitorCondition), s = tostring(properties.essentials.startDateTime), r = tostring(properties.essentials.monitorConditionResolvedDateTime)"
Q=$(jq -n --arg s "$SUB" --arg q "$KQ" '{subscriptions: [$s], query: $q}')

code() {
	curl -4 -s -o /dev/null --max-time 10 -w '%{http_code}' "$1" 2>/dev/null || echo 000
}

mkdir -p "$(dirname "$OUT")"
printf 'ts_utc\tbe_health\tbe_items\tfe_api_health\tbe_sha\talert_5xx\talert_started\talert_resolved\n' >"$OUT"
echo "# $(date -u +%FT%TZ) watcher $BE mỗi ${INTERVAL}s trong ${DURATION}s → $OUT" >&2
trap 'echo "# $(date -u +%FT%TZ) dừng" >&2; exit 130' INT TERM

end=$((SECONDS + DURATION))
while ((SECONDS < end)); do
	tick=$((SECONDS + INTERVAL))
	sha=$(curl -4 -s --max-time 10 "$BE/version" 2>/dev/null | jq -r '.sha // empty' 2>/dev/null | cut -c1-7)
	alert=$(az rest --method post --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
		--body "$Q" --query "data[0]" -o json 2>/dev/null | jq -r '[.c, .s, .r] | map(. // "-" | if . == "" then "-" else . end) | join("|")' 2>/dev/null)
	IFS='|' read -r ac as ar <<<"${alert:-||}"
	line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$(date -u +%FT%TZ)" "$(code "$BE/health")" "$(code "$BE/items")" \
		"$(code "$FE/api/health")" "${sha:--}" "${ac:--}" "${as:--}" "${ar:--}")
	echo "$line" >>"$OUT"
	echo "$line" >&2
	while ((SECONDS < tick)); do sleep 1; done
done

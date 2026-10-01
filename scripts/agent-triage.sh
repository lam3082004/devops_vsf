#!/usr/bin/env bash
# D23 — "agent đọc sự cố": tóm tắt sự cố 5xx của rg-vsf-dev trong N giờ gần nhất,
# CHỈ bằng quyền đọc của id-agent-triage (infra/app/agent-permissions.tf):
#   - Log Analytics Reader trên workspace → KQL (bảng của M11, docs/logging.md)
#   - vsf-agent-alert-reader trên RG     → alert đang bắn (Resource Graph) + metric
# Không đọc cấu hình Web App, không đọc secret, không ghi gì. Agent theo luật cố định
# (không LLM): gom đúng các truy vấn mà runbook.md bảo người trực chạy tay.
#
# Chạy trong .github/workflows/agent-triage.yml (mode=triage) sau `azure/login`.
# Chạy tay được bằng `az login` của mình — nhưng khi đó là quyền của mình, không phải
# của agent, nên không dùng làm bằng chứng quyền.
#
# Dùng:
#   scripts/agent-triage.sh [--hours 1] [--rg rg-vsf-dev] [--out FILE]
# Kết quả: markdown ra FILE (mặc định stdout) và nối vào $GITHUB_STEP_SUMMARY nếu có.
#
# Gọi API bằng `az rest` thay vì `az monitor log-analytics query` / `az graph query`:
# hai lệnh đó cần extension (log-analytics bản preview, resource-graph) và tự cài lúc
# chạy — thêm phụ thuộc không ghim version vào runner.

set -uo pipefail
export LC_ALL=C

HOURS=1
RG="rg-vsf-dev"
OUT=""

usage() {
	sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--hours)
		HOURS="$2"
		shift 2
		;;
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

if ! [[ "$HOURS" =~ ^[0-9]+$ ]] || ((HOURS < 1 || HOURS > 72)); then
	# Workspace giữ 30 ngày, nhưng quét rộng = đọc nhiều dữ liệu cá nhân hơn (IP, nội dung
	# lỗi) mà không giúp gì cho một sự cố đang diễn ra.
	echo "!! --hours phải là số 1–72" >&2
	exit 2
fi

SUB=$(az account show --query id -o tsv) || {
	echo "!! chưa đăng nhập Azure" >&2
	exit 1
}

# ---------- helpers ----------

# Resource Graph: chỉ trả về thứ danh tính hiện tại ĐỌC ĐƯỢC — agent không có quyền đọc
# RG nên không liệt kê được Web App/Key Vault, chỉ thấy workspace và alert.
graph() {
	jq -n --arg q "$1" --arg s "$SUB" '{subscriptions: [$s], query: $q}' >"$TMP/graph.json"
	az rest --method post \
		--url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" \
		--body "@$TMP/graph.json" --query data -o json
}

# KQL qua API data plane của Log Analytics. In bảng markdown; 0 dòng thì in "_(không có dòng nào)_".
kql() {
	jq -n --arg q "$1" --arg t "PT${HOURS}H" '{query: $q, timespan: $t}' >"$TMP/kql.json"
	az rest --method post \
		--url "https://api.loganalytics.io/v1/workspaces/$WS_CID/query" \
		--resource "https://api.loganalytics.io" \
		--body "@$TMP/kql.json" -o json >"$TMP/kql.out" || return 1
	jq -r '
		.tables[0] as $t
		| if ($t.rows | length) == 0 then "_(không có dòng nào)_"
		  else
		    ("| " + ([$t.columns[].name] | join(" | ")) + " |"),
		    ("|" + ([$t.columns[] | "---"] | join("|")) + "|"),
		    ($t.rows[] | "| " + (map(tostring | gsub("\\|"; "\\|") | gsub("\n"; " ")) | join(" | ")) + " |")
		  end' "$TMP/kql.out"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
[[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")" && : >"$OUT"
emit() {
	if [[ -n "$OUT" ]]; then cat >>"$OUT"; else cat; fi
}

# ---------- 1. tìm workspace ----------
ws=$(graph "resources | where type =~ 'microsoft.operationalinsights/workspaces' and resourceGroup =~ '$RG' | project name, id, customerId = tostring(properties.customerId)") || {
	echo "!! không đọc được Resource Graph" >&2
	exit 1
}
WS_NAME=$(jq -r '.[0].name // empty' <<<"$ws")
WS_CID=$(jq -r '.[0].customerId // empty' <<<"$ws")
if [[ -z "$WS_CID" ]]; then
	# Môi trường tắt (make down) hoặc danh tính chưa có quyền: cả hai đều không phải sự cố app.
	echo "!! không thấy Log Analytics workspace trong $RG (môi trường tắt, hoặc thiếu role Log Analytics Reader)" >&2
	exit 1
fi

# Bỏ probe/health của nền tảng, đúng bộ lọc của alert 5xx (infra/app/alerts.tf) và Workbook.
PROD="where _ResourceId has '/sites/' and _ResourceId !has '/slots/' | where CsUriStem !in ('/health', '/version', '/api/version') | extend app = tostring(split(_ResourceId, '/')[8])"

{
	echo "## Agent đọc sự cố: $RG, ${HOURS} giờ gần nhất"
	echo
	echo "Chạy lúc $(date -u +%FT%TZ) · workspace \`$WS_NAME\` · danh tính: \`$(az account show --query user.name -o tsv)\`"
	echo
} | emit

# ---------- 2. alert ----------
alerts=$(graph "alertsmanagementresources | where type =~ 'microsoft.alertsmanagement/alerts' | where tostring(properties.essentials.targetResourceGroup) =~ '$RG' | where todatetime(properties.essentials.startDateTime) > ago(${HOURS}h) or tostring(properties.essentials.monitorCondition) == 'Fired' | project name, severity = tostring(properties.essentials.severity), condition = tostring(properties.essentials.monitorCondition), state = tostring(properties.essentials.alertState), started = tostring(properties.essentials.startDateTime), resolved = tostring(properties.essentials.monitorConditionResolvedDateTime) | order by started desc") || alerts="ERR"
{
	echo "### 1. Alert (Fired trong ${HOURS} giờ, hoặc vẫn đang Fired)"
	echo
	if [[ "$alerts" == "ERR" ]]; then
		echo "_(không đọc được alert — xem log job)_"
	elif [[ $(jq length <<<"$alerts") -eq 0 ]]; then
		echo "_(không có alert nào)_"
	else
		echo "| alert | sev | điều kiện | trạng thái | bắt đầu | resolved |"
		echo "|---|---|---|---|---|---|"
		jq -r '.[] | "| \(.name) | \(.severity) | \(.condition) | \(.state) | \(.started) | \(.resolved) |"' <<<"$alerts"
	fi
	echo
} | emit
fired=$(jq '[.[]? | select(.condition == "Fired")] | length' <<<"${alerts/ERR/[]}")

# ---------- 3. 5xx theo app ----------
{
	echo "### 2. Tỉ lệ 5xx theo app (production, bỏ probe)"
	echo
	kql "AppServiceHTTPLogs | $PROD | summarize total = count(), errors_5xx = countif(ScStatus >= 500) by app | extend fail_pct = round(100.0 * errors_5xx / total, 2) | order by errors_5xx desc" || echo "_(query lỗi)_"
	echo
	echo "### 3. Endpoint lỗi nhiều nhất"
	echo
	kql "AppServiceHTTPLogs | $PROD | where ScStatus >= 500 | summarize errors = count(), first_seen = min(TimeGenerated), last_seen = max(TimeGenerated) by app, CsUriStem, ScStatus | top 5 by errors" || echo "_(query lỗi)_"
	echo
} | emit
kql "AppServiceHTTPLogs | $PROD | summarize e = countif(ScStatus >= 500)" >/dev/null
errors_5xx=$(jq -r '.tables[0].rows[0][0] // 0' "$TMP/kql.out")

# ---------- 4. log lỗi của app (Q5 docs/logging.md) ----------
# Chỉ lấy tên event/error và trace_id, KHÔNG lấy nguyên dòng log: dòng log có thể chứa
# dữ liệu người dùng (rủi ro còn lại, evidence/agent.md).
{
	echo "### 4. Lỗi trong log app (level=error hoặc status ≥ 500)"
	echo
	kql "AppServiceConsoleLogs | extend app = tostring(split(_ResourceId, '/')[8]) | extend log = parse_json(ResultDescription) | where tostring(log.level) == 'error' or toint(log.status) >= 500 | summarize count_ = count(), last_seen = max(TimeGenerated), sample_trace_id = take_any(tostring(log.trace_id)) by app, event = tostring(log.event), path = tostring(log.path), error = tostring(log.error) | top 8 by count_" || echo "_(query lỗi)_"
	echo
} | emit
# Tên event thật của be là `db_error` / body `database_unavailable` (drill 1 D24: bản đầu chỉ dò
# chữ 'database' nên bỏ sót 145 dòng db_error — ai-failure-log.md #44).
kql "AppServiceConsoleLogs | extend log = parse_json(ResultDescription) | where tostring(log.event) startswith 'db_' or tostring(log.error) has_any ('database', 'Connect Timeout', 'MySql') | count" >/dev/null
db_errors=$(jq -r '.tables[0].rows[0][0] // 0' "$TMP/kql.out")

# ---------- 5. exception (App Insights, workspace-based) ----------
{
	echo "### 5. Exception gần nhất (App Insights)"
	echo
	kql "AppExceptions | summarize count_ = count(), last_seen = max(TimeGenerated), sample_operation_id = take_any(OperationId) by AppRoleName, ExceptionType, method = tostring(split(Method, '(')[0]) | top 5 by count_" || echo "_(query lỗi)_"
	echo
	echo "### 6. Container khởi động lại / dừng"
	echo
	kql "AppServicePlatformLogs | extend app = tostring(split(_ResourceId, '/')[8]), slot = iff(_ResourceId has '/slots/', 'staging', 'production') | where Message has_any ('Stopping container', 'Container is terminated', 'Starting container') | summarize events = count(), last_seen = max(TimeGenerated) by app, slot" || echo "_(query lỗi)_"
	echo
} | emit

# ---------- 6. metric Http5xx (quyền metrics/read) ----------
# ID Web App lấy từ log, không từ ARM: agent không có quyền đọc Web App.
kql "AppServiceHTTPLogs | where _ResourceId has '/sites/' and _ResourceId !has '/slots/' | distinct _ResourceId" >/dev/null
mapfile -t app_ids < <(jq -r '.tables[0].rows[][0]' "$TMP/kql.out")
{
	echo "### 7. Metric \`Http5xx\` (tổng theo app, ${HOURS} giờ)"
	echo
	if ((${#app_ids[@]} == 0)); then
		echo "_(không có app nào trong log)_"
	else
		echo "| app | Http5xx | Requests |"
		echo "|---|---|---|"
		for id in "${app_ids[@]}"; do
			m=$(az monitor metrics list --resource "$id" --metric Http5xx Requests --aggregation Total \
				--offset "${HOURS}h" --interval PT1H -o json 2>"$TMP/metric.err") || {
				echo "| ${id##*/} | lỗi: $(head -c 120 "$TMP/metric.err" | tr '\n' ' ') | |"
				continue
			}
			jq -r --arg a "${id##*/}" '
				[.value[] | {(.name.value): ([.timeseries[]?.data[]?.total // 0] | add // 0)}] | add
				| "| \($a) | \(.Http5xx) | \(.Requests) |"' <<<"$m"
		done
	fi
	echo
} | emit

# ---------- 7. kết luận theo luật ----------
{
	echo "### Kết luận (luật cố định, không phải LLM)"
	echo
	if ((errors_5xx == 0 && fired == 0)); then
		echo "- Không có 5xx production và không có alert đang Fired trong ${HOURS} giờ: **không có sự cố**."
	else
		echo "- ${errors_5xx} response 5xx production · ${fired} alert đang Fired."
		if ((db_errors > 0)); then
			echo "- Có ${db_errors} dòng log lỗi liên quan **database**: nghi DB không tới được. Runbook bước \"phân loại\": so outbound IP của \`be\` với firewall MySQL (agent không đọc được firewall, người trực phải kiểm)."
		fi
		echo "- Lấy \`sample_trace_id\` ở mục 4 hoặc \`sample_operation_id\` ở mục 5, tra tiếp theo runbook.md bước 3 (Workbook, mục trace)."
	fi
	echo "- Agent **không** sửa gì. Mọi hành động phục hồi (apply, swap, restart) là việc của người trực theo runbook.md."
} | emit

[[ -n "$OUT" && -n "${GITHUB_STEP_SUMMARY:-}" ]] && cat "$OUT" >>"$GITHUB_STEP_SUMMARY"
exit 0

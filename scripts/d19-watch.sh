#!/usr/bin/env bash
# M7 (D19) — theo dõi autoscale: mỗi 30s ghi một dòng số instance + CPU/Memory của
# App Service Plan, để đối chiếu timeline 1 → 2 → 1 với log tải (scripts/load.sh) và
# log M2 (scripts/m2-poll.sh) cùng đồng hồ UTC. Kế hoạch: notes/d19-prep.md A3.
#
# CHỈ ĐỌC: chỉ `az ... show/list`, không lệnh ghi nào, không phát sinh chi phí. Cần
# `az login` sẵn và subscription đúng.
#
# Dùng:
#   scripts/d19-watch.sh [--rg rg-vsf-dev] [--plan asp-vsf-dev] [--interval 30]
#                        [--out evidence/raw/d19-watch-....log]
# Dừng: Ctrl+C (hoặc SIGTERM).
#
# Cột log (TSV, UTC):
#   ts_utc  capacity  be_inst  fe_inst  metric_min_utc  cpu_avg  cpu_max  mem_avg
#   capacity = sku.capacity của plan (số instance autoscale đang giữ).
#   be_inst/fe_inst = `az webapp list-instances` của slot production từng app.
#   metric_min_utc = phút gần nhất có số liệu của metric plan (PT1M) — metric trễ
#   1–3 phút so với ts_utc, đọc hai cột này cạnh nhau. `-` = az lỗi/không có số liệu.

# Không `set -e`: một lần az lỗi (mạng) không được giết vòng lặp.
set -uo pipefail
export LC_ALL=C

RG="rg-vsf-dev"
PLAN="asp-vsf-dev"
INTERVAL=30
OUT="evidence/raw/d19-watch-$(date -u +%Y%m%d-%H%M%S).log"

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
	--rg)
		RG="$2"
		shift 2
		;;
	--plan)
		PLAN="$2"
		shift 2
		;;
	--interval)
		INTERVAL="$2"
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

die() {
	echo "!! $*" >&2
	exit 2
}

[[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -ge 10 ]] || die "--interval phải là số nguyên ≥ 10"
[[ -n "${EPOCHSECONDS:-}" ]] || die "cần bash ≥ 5 (EPOCHSECONDS)"
for bin in az jq date timeout; do
	command -v "$bin" >/dev/null || die "thiếu $bin"
done
[[ ! -e "$OUT" ]] || die "$OUT đã tồn tại, chọn --out khác"

PLAN_ID="$(az appservice plan show -g "$RG" -n "$PLAN" --query id -o tsv)" || die "không đọc được plan $RG/$PLAN"
# Tên app đọc từ Azure, không đoán: mọi web app gắn vào plan này, `be` = app-*, `fe` = fe-*.
APPS="$(az webapp list -g "$RG" --query "[?serverFarmId=='$PLAN_ID'].name" -o tsv)" || die "không liệt kê được web app"
BE_APP="$(grep '^app-' <<<"$APPS" | head -1)"
FE_APP="$(grep '^fe-' <<<"$APPS" | head -1)"
[[ -n "$BE_APP" && -n "$FE_APP" ]] || die "không tìm thấy app-*/fe-* trên plan $PLAN (thấy: $APPS)"

mkdir -p "$(dirname "$OUT")"
printf 'ts_utc\tcapacity\tbe_inst\tfe_inst\tmetric_min_utc\tcpu_avg\tcpu_max\tmem_avg\n' >"$OUT"
{
	echo "# d19-watch start $(date -u +%Y-%m-%dT%H:%M:%SZ) plan=$RG/$PLAN be=$BE_APP fe=$FE_APP interval=${INTERVAL}s"
} >>"$OUT"

# Mỗi lệnh az tối đa 20s: D19 Pha C một lần az treo ~4 phút (mạng đứt) làm mất mẫu. Hết
# giờ → cột đó ghi `-`.
AZ_TIMEOUT=20
TMPD="$(mktemp -d)"
AZ_PID=""

# Một lệnh az, kết quả vào file $1. Chạy nền + `wait` (không dùng $(...)): bash chỉ chạy
# trap sau khi lệnh foreground xong, nên az foreground làm Ctrl+C/SIGTERM trễ tới
# AZ_TIMEOUT giây mỗi lệnh (review vòng 2). `wait` thì bị trap cắt ngang ngay.
az_q() {
	local out="$1"
	shift
	: >"$out"
	timeout "$AZ_TIMEOUT" az "$@" >"$out" 2>/dev/null &
	AZ_PID=$!
	wait "$AZ_PID" 2>/dev/null
	AZ_PID=""
}

num_or_dash() {
	[[ "$1" =~ ^[0-9]+$ ]] && echo "$1" || echo "-"
}

# Dừng giữa chừng (STOP=1) → trả 1, không ghi dòng thiếu cột.
sample() {
	local ts cap be fe m t cpu cmax mem
	ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	az_q "$TMPD/cap" appservice plan show --ids "$PLAN_ID" --query sku.capacity -o tsv
	((STOP == 0)) || return 1
	az_q "$TMPD/be" webapp list-instances -g "$RG" -n "$BE_APP" --query 'length(@)' -o tsv
	((STOP == 0)) || return 1
	az_q "$TMPD/fe" webapp list-instances -g "$RG" -n "$FE_APP" --query 'length(@)' -o tsv
	((STOP == 0)) || return 1
	# 6 phút gần nhất, lấy phút MỚI NHẤT có số liệu CPU (phút đang chạy thường rỗng).
	az_q "$TMPD/m" monitor metrics list --resource "$PLAN_ID" --metric CpuPercentage MemoryPercentage \
		--interval PT1M --aggregation Average Maximum \
		--start-time "$(date -u -d '-6 min' +%Y-%m-%dT%H:%M:%SZ)" -o json
	((STOP == 0)) || return 1
	cap="$(num_or_dash "$(tr -d '[:space:]' <"$TMPD/cap")")"
	be="$(num_or_dash "$(tr -d '[:space:]' <"$TMPD/be")")"
	fe="$(num_or_dash "$(tr -d '[:space:]' <"$TMPD/fe")")"
	m="$(jq -r '
			[.value[] | {k: .name.value, d: [.timeseries[0].data[]? | select(.average != null)]}]
			| (map(select(.k == "CpuPercentage"))[0].d | last) as $c
			| (map(select(.k == "MemoryPercentage"))[0].d // [] | map(select(.timeStamp == $c.timeStamp)) | last) as $m
			| if $c == null then "-\t-\t-\t-"
			  else [$c.timeStamp[0:16], ($c.average | floor), ($c.maximum | floor), (($m.average // null) | if . == null then "-" else floor end)] | map(tostring) | join("\t") end
		' "$TMPD/m" 2>/dev/null)"
	[[ -n "$m" ]] || m=$'-\t-\t-\t-'
	IFS=$'\t' read -r t cpu cmax mem <<<"$m"
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "$cap" "$be" "$fe" "$t" "$cpu" "$cmax" "$mem" >>"$OUT"
	printf '%s cap=%s be=%s fe=%s | %s cpu=%s%% (max %s) mem=%s%%\n' "${ts:11:8}" "$cap" "$be" "$fe" "${t:11}" "$cpu" "$cmax" "$mem"
}

STOP=0
# Dừng: đánh dấu + giết lệnh az đang chạy (timeout chuyển tín hiệu cho az).
# shellcheck disable=SC2317 # gọi gián tiếp qua trap
on_stop() {
	STOP=1
	[[ -z "$AZ_PID" ]] || kill "$AZ_PID" 2>/dev/null
}
trap on_stop INT TERM
echo ">> ghi $OUT mỗi ${INTERVAL}s. Ctrl+C để dừng." >&2
next=$EPOCHSECONDS
while ((STOP == 0)); do
	sample
	next=$((next + INTERVAL))
	# Một lượt az chậm quá INTERVAL (mạng đứt): chạy lượt sau liền MỘT lần rồi neo lại
	# nhịp từ bây giờ, bỏ các mốc đã lỡ. Không bỏ thì sau một lần az treo vài phút,
	# vòng lặp bắn dồn mỗi ~8s để "đuổi" các mốc cũ (đã gặp ở Pha C, notes/d19.md).
	((next > EPOCHSECONDS)) || next=$EPOCHSECONDS
	# `sleep & wait` để Ctrl+C cắt ngang ngay.
	while ((STOP == 0 && EPOCHSECONDS < next)); do
		sleep 1 &
		wait $! 2>/dev/null
	done
done
rm -rf "$TMPD"
echo "# d19-watch stop $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT"
exit 0

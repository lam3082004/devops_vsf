#!/usr/bin/env bash
# M7 (D19) — test tải ngắn cho autoscale: N worker song song, mỗi worker lặp GET
# `be` `/load?seconds=S` tới khi hết `--duration`, rồi DỪNG HẲN. Kế hoạch:
# notes/d19-prep.md A2 (quyết định D: 3 worker × seconds=55, trần 8 phút).
#
# ⚠️ TỐN TIỀN khi chạy lên production: đẩy CPU plan > 70% → autoscale thêm instance
# thứ 2. Chỉ chạy sau khi người dùng xác nhận trong phiên. Không gọi az/terraform.
# Máy chạy phải nằm trong whitelist của `be` — nếu không, mọi dòng sẽ là 403.
#
# Dùng:
#   scripts/load.sh --url https://app-vsf-xxx.azurewebsites.net \
#                   [--workers 3] [--seconds 55] [--duration 480] \
#                   [--max-seconds 60] [--out evidence/raw/d19-load-....log]
# Dừng sớm: Ctrl+C (hoặc SIGTERM) → huỷ MỌI request đang bay, in tóm tắt.
#
# Giới hạn cứng (từ chối trước khi gửi request nào):
#   --seconds ≤ --max-seconds (mặc định 60 = LOAD_MAX_SECONDS mặc định của `be`;
#     vượt thì `be` trả 400 và CPU không lên — bẫy Q3). --max-seconds chỉ đổi khi
#     app setting LOAD_MAX_SECONDS của `be` đã đổi, và phải khớp nó.
#   --duration ≤ 480 (8 phút, TỔNG, không phải mỗi worker) · --workers 1..4.
# Worker không bắt đầu request mới nếu nó không kịp xong trước hạn (giờ bắt đầu +
# seconds + 12s dư > hạn), nên phía server không đốt CPU quá hạn. 12s: D19 đo được
# request 55s mất tới 66,2s qua WARP (dư 11s).
# Tới hạn mà còn request đang bay thì bị huỷ như Ctrl+C.
# Huỷ curl KHÔNG dừng được vòng lặp đốt CPU phía server (LoadService không nhận
# cancellation): sau Ctrl+C, server còn đốt tối đa `seconds` giây nữa.
#
# Cột log (TSV, UTC):
#   ts_start_utc  worker  http_code  curl_exit  time_total_s  body
#   curl_exit=aborted: request bị huỷ lúc dừng (hết hạn hoặc Ctrl+C). body = 120 byte
#   đầu, xuống dòng/tab thay bằng dấu cách.

# Không `set -e`: một curl lỗi không được giết worker (bẫy P1 của D18).
set -uo pipefail
export LC_ALL=C

URL=""
WORKERS=3
SECS=55
DURATION=480
MAX_SECS=60
MAX_TIME=75
OUT="evidence/raw/d19-load-$(date -u +%Y%m%d-%H%M%S).log"

usage() {
	sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--url)
		URL="${2%/}"
		shift 2
		;;
	--workers)
		WORKERS="$2"
		shift 2
		;;
	--seconds)
		SECS="$2"
		shift 2
		;;
	--duration)
		DURATION="$2"
		shift 2
		;;
	--max-seconds)
		MAX_SECS="$2"
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

[[ -n "$URL" ]] || die "thiếu --url"
# ^[1-9]: số có 0 đứng đầu (070) bị (( )) đọc theo hệ bát phân (= 56) → qua kiểm tra
# trong khi URL vẫn gửi "070" = 70 > 60 → 400 hàng loạt (bẫy Q3 lọt qua).
for v in WORKERS SECS DURATION MAX_SECS; do
	[[ "${!v}" =~ ^[1-9][0-9]*$ ]] || die "$v phải là số nguyên dương, không có 0 đứng đầu"
done
((MAX_SECS >= 1 && MAX_SECS <= 300)) || die "--max-seconds phải trong 1..300 (giới hạn của LOAD_MAX_SECONDS)"
((SECS >= 1 && SECS <= MAX_SECS)) || die "--seconds $SECS ngoài 1..$MAX_SECS — be sẽ trả 400 (bẫy Q3)"
((WORKERS >= 1 && WORKERS <= 4)) || die "--workers phải trong 1..4"
((DURATION <= 480)) || die "--duration $DURATION > 480 — trần cứng 8 phút (bẫy Q5/Q6)"
# Dư cho độ trễ mạng của request cuối (xem đầu file) + 1s vì EPOCHSECONDS làm tròn xuống.
SLACK=12
((DURATION >= SECS + SLACK + 1)) || die "--duration phải ≥ --seconds + $((SLACK + 1)), nếu không sẽ không có request nào"
# curl phải chờ lâu hơn thời gian server đốt, nếu không mọi request đều timeout phía
# client trong khi server vẫn đốt (bẫy Q4). 75 = 55 + dư cho độ trễ WARP.
((MAX_TIME > SECS + 10)) || MAX_TIME=$((SECS + 20))
[[ -n "${EPOCHSECONDS:-}" ]] || die "cần bash ≥ 5 (EPOCHSECONDS)"
command -v curl >/dev/null || die "thiếu curl"
# Không ghi đè log thô cũ — log thô là bằng chứng.
[[ ! -e "$OUT" ]] || die "$OUT đã tồn tại, chọn --out khác"
mkdir -p "$(dirname "$OUT")"
TMP="$(mktemp -d)"

START=$EPOCHSECONDS
DEADLINE=$((START + DURATION))

printf 'ts_start_utc\tworker\thttp_code\tcurl_exit\ttime_total_s\tbody\n' >"$OUT"
{
	echo "# load start $(date -u -d "@$START" +%Y-%m-%dT%H:%M:%SZ) deadline $(date -u -d "@$DEADLINE" +%Y-%m-%dT%H:%M:%SZ)"
	echo "# url=$URL/load?seconds=$SECS workers=$WORKERS duration=${DURATION}s max_time=${MAX_TIME}s"
} >>"$OUT"

# Một worker. Curl chạy nền + `wait` để trap cắt ngang được lúc đang chờ (bash chỉ
# chạy trap sau khi lệnh foreground xong — curl foreground thì Ctrl+C phải chờ tới 75s).
worker() {
	local id="$1" pid="" ts rc code t body
	local bodyf="$TMP/w$id.body" metaf="$TMP/w$id.meta"
	# shellcheck disable=SC2317 # gọi gián tiếp qua trap bên dưới
	abort() {
		# INT (cả nhóm tiến trình) và TERM (từ script cha) có thể tới cùng lúc —
		# chỉ xử lý một lần, không ghi hai dòng aborted.
		trap '' INT TERM
		if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
			printf '%s\t%s\t000\taborted\t-\t-\n' "$ts" "$id" >>"$OUT"
		fi
		exit 0
	}
	trap abort INT TERM
	while ((EPOCHSECONDS + SECS + SLACK <= DEADLINE)); do
		ts="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
		: >"$bodyf"
		curl -4 -s --max-time "$MAX_TIME" -o "$bodyf" -w '%{http_code} %{time_total}' \
			"$URL/load?seconds=$SECS" >"$metaf" &
		pid=$!
		wait "$pid"
		rc=$?
		pid=""
		read -r code t <"$metaf"
		[[ "${code:-}" =~ ^[0-9]{3}$ ]] || code="000"
		[[ "${t:-}" =~ ^[0-9.]+$ ]] || t="-"
		body="$(head -c 120 "$bodyf" | tr '\n\t\r' '   ')"
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "$id" "$code" "$rc" "$t" "${body:--}" >>"$OUT"
		printf '%s w%s %s exit=%s %ss\n' "${ts:11:8}" "$id" "$code" "$rc" "$t"
		# Lỗi nhanh (403, 400, mạng) thì đừng dồn request dày đặc — nghỉ 1s.
		[[ "$code" == "200" ]] || sleep 1
	done
}

STOP=0
trap 'STOP=1' INT TERM

pids=()
for ((i = 1; i <= WORKERS; i++)); do
	worker "$i" &
	pids+=($!)
done
echo ">> $WORKERS worker, hạn $(date -u -d "@$DEADLINE" +%H:%M:%SZ), ghi $OUT. Ctrl+C để dừng sớm." >&2

alive() {
	local p
	for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && return 0; done
	return 1
}
# `sleep & wait` để trap INT/TERM cắt ngang ngay, không chờ hết giây.
while ((STOP == 0 && EPOCHSECONDS < DEADLINE)) && alive; do
	sleep 1 &
	wait $! 2>/dev/null
done

REASON="hết hạn"
((STOP == 1)) && REASON="dừng tay (Ctrl+C/SIGTERM)"
# Tín hiệu thứ hai (Ctrl+C lần 2, hoặc TERM cho cha + INT cho cả nhóm) trong lúc `wait`
# làm `wait` trả về sớm → tóm tắt in trước khi worker ghi dòng `aborted`. Bỏ qua tín
# hiệu từ đây, và chờ tới khi không còn worker nào sống.
trap '' INT TERM
kill -TERM "${pids[@]}" 2>/dev/null
while alive; do
	wait "${pids[@]}" 2>/dev/null
done
rm -rf "$TMP"

{
	echo "# load stop $(date -u +%Y-%m-%dT%H:%M:%SZ) lý do: $REASON"
	grep -v '^#' "$OUT" | tail -n +2 | awk -F'\t' '
		{ n++; k = $3 " exit=" $4; c[k]++; if ($4 == "aborted") ab++ }
		END {
			printf "# requests=%d\n", n
			for (k in c) printf "#   %s: %d\n", k, c[k]
			if (ab) printf "# %d request bị huỷ: server có thể còn đốt CPU tới %ss sau giờ dừng\n", ab, secs
		}' secs="$SECS"
} | tee -a "$OUT"
exit 0

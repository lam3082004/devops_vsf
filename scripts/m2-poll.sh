#!/usr/bin/env bash
# M2 (D18) — poll production be `/version` + fe `/api/version` 1 lần/giây trong lúc
# CD swap, ghi log thô TSV để chứng minh zero-downtime. Kế hoạch: notes/d18-prep.md A1.
#
# CHỈ ĐỌC: chỉ gửi GET tới URL công khai, không gọi az/terraform, không phát sinh chi
# phí. Máy chạy phải nằm trong whitelist (IP cong-ty) — nếu không, mọi dòng sẽ là 403.
#
# Dùng:
#   scripts/m2-poll.sh --be-url https://app-vsf-xxx.azurewebsites.net \
#                      --fe-url https://fe-vsf-xxx.azurewebsites.net \
#                      [--out evidence/raw/m2-....log] [--duration GIÂY] \
#                      [--extra-fe-page /|none] [--max-time 3]
# Dừng: Ctrl+C (hoặc SIGTERM) → in tóm tắt ra màn hình + cuối file log (dòng `#`).
#
# Nhịp: mỗi giây bắn một tick chạy nền, KHÔNG chờ tick trước xong — một request chậm
# không đẩy lùi các giây sau. Trong một tick, be/fe/fe-page gọi song song. Vì vậy dòng
# log có thể lệch thứ tự khi một request chậm hơn 1s; cột `tick` + `ts_utc_ms` (giờ BẮT
# ĐẦU request) là thứ tự thật, tóm tắt tự sắp lại.
#
# Cột log (TSV, UTC):
#   ts_utc_ms  tick  svc  http_code  sha  curl_exit  time_total_s
#   svc ∈ {be, fe, fe-page}. fe-page chỉ tham khảo (quyết định D), không tính vào M2.
#   Mọi response ≠ 200, hoặc 200 mà không đọc được sha: 300 byte đầu của body vào
#   <out>.bodies (known-issues #20 — phân biệt 403 nền tảng / whitelist / app).

# Không `set -e`: một curl/jq lỗi không được giết vòng lặp (bẫy P1).
set -uo pipefail
export LC_ALL=C

BE_URL=""
FE_URL=""
OUT="evidence/raw/m2-$(date -u +%Y%m%d-%H%M%S).log"
DURATION=0
FE_PAGE="/"
MAX_TIME=3

usage() {
	sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--be-url)
		BE_URL="${2%/}"
		shift 2
		;;
	--fe-url)
		FE_URL="${2%/}"
		shift 2
		;;
	--out)
		OUT="$2"
		shift 2
		;;
	--duration)
		DURATION="$2"
		shift 2
		;;
	--extra-fe-page)
		FE_PAGE="$2"
		shift 2
		;;
	--max-time)
		MAX_TIME="$2"
		shift 2
		;;
	-h | --help) usage 0 ;;
	*)
		echo "!! tham số lạ: $1" >&2
		usage 2
		;;
	esac
done

if [[ -z "$BE_URL" || -z "$FE_URL" ]]; then
	echo "!! thiếu --be-url hoặc --fe-url" >&2
	usage 2
fi
if [[ ! "$DURATION" =~ ^[0-9]+$ ]]; then
	echo "!! --duration phải là số nguyên giây" >&2
	exit 2
fi
for bin in curl jq date awk; do
	command -v "$bin" >/dev/null || {
		echo "!! thiếu $bin" >&2
		exit 2
	}
done
# Không ghi đè log thô cũ — log thô là bằng chứng, không được sửa.
if [[ -e "$OUT" ]]; then
	echo "!! $OUT đã tồn tại, chọn --out khác" >&2
	exit 2
fi
mkdir -p "$(dirname "$OUT")"
BODIES="$OUT.bodies"

printf 'ts_utc_ms\ttick\tsvc\thttp_code\tsha\tcurl_exit\ttime_total_s\n' >"$OUT"
{
	echo "# m2-poll start $(date -u +%Y-%m-%dT%H:%M:%SZ) host=$(hostname)"
	echo "# be=$BE_URL/version fe=$FE_URL/api/version fe-page=${FE_PAGE} max_time=${MAX_TIME}s"
} >>"$OUT"
: >"$BODIES"

# Một request. Ghi đúng một dòng TSV (một lần write, append nguyên tử với dòng ngắn).
probe() {
	local tick="$1" svc="$2" url="$3"
	local ts resp rc t rest code body sha snippet
	ts="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
	# Một lần gọi: body + mã + thời gian. `$?` bắt ngay sau lệnh, không qua `|| ...`
	# (bẫy P2 — `|| echo 000` in ra `000000`).
	resp="$(curl -4 -s --max-time "$MAX_TIME" -w $'\n%{http_code}\n%{time_total}' "$url")"
	rc=$?
	t="${resp##*$'\n'}"
	rest="${resp%$'\n'*}"
	code="${rest##*$'\n'}"
	if [[ "$rest" == *$'\n'* ]]; then body="${rest%$'\n'*}"; else body=""; fi
	[[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
	[[ "$t" =~ ^[0-9.]+$ ]] || t="-"

	sha="-"
	if [[ "$svc" != "fe-page" ]]; then
		sha="$(printf '%s' "$body" | jq -r '.sha // empty' 2>/dev/null)"
		[[ -n "$sha" ]] || sha="-"
	fi

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "$tick" "$svc" "$code" "$sha" "$rc" "$t" >>"$OUT"
	printf '%s %-7s %s %-8.8s exit=%s %ss\n' "${ts:11:12}" "$svc" "$code" "$sha" "$rc" "$t"

	if [[ "$code" != "200" || ("$svc" != "fe-page" && "$sha" == "-") ]]; then
		snippet="$(printf '%s' "$body" | head -c 300 | tr '\n\t\r' '   ')"
		printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$svc" "$code" "$rc" "$snippet" >>"$BODIES"
	fi
}

tick_once() {
	local tick="$1"
	# Ctrl+C gửi SIGINT cho cả nhóm tiến trình. Subshell nền KHÔNG tự bỏ qua nó khi
	# script cha có `trap ... INT` (đã đo: mất dòng của request đang bay). Bỏ qua tường
	# minh ở đây — curl con thừa hưởng — để request đang bay vẫn ghi xong dòng log.
	trap '' INT
	probe "$tick" be "$BE_URL/version" &
	probe "$tick" fe "$FE_URL/api/version" &
	if [[ "$FE_PAGE" != "none" ]]; then
		probe "$tick" fe-page "$FE_URL$FE_PAGE" &
	fi
	wait
}

# Tóm tắt đọc lại từ file log (không từ biến trong RAM) — cùng một nguồn với bằng chứng.
summarize() {
	grep -v '^#' "$OUT" | tail -n +2 | sort -t $'\t' -k1,1 | awk -F'\t' '
	{
		svc = $3; code = $4; sha = $5; ex = $6; ts = $1; tk = $2
		n[svc]++
		if (ex != 0 || code == "000") cli[svc]++
		else if (code != "200") srv[svc]++
		if (sha != "-") {
			if (!((svc, sha) in first)) { first[svc, sha] = ts; order[svc] = order[svc] " " sha }
			last[svc, sha] = ts
			if (sha != cur[svc]) { seg[svc]++; segs[svc] = segs[svc] sprintf("\n#     %s  %s", ts, sha); cur[svc] = sha }
			tsha[tk, svc] = sha
		}
		if (tk > maxtk) maxtk = tk
	}
	END {
		split("be fe fe-page", svcs, " ")
		for (i = 1; i <= 3; i++) {
			s = svcs[i]
			if (!(s in n)) continue
			printf "# [%s] requests=%d  server_non200=%d  client_err=%d%s\n", s, n[s], srv[s] + 0, cli[s] + 0, (s == "fe-page" ? "  (chỉ tham khảo)" : "")
			if (s == "fe-page") continue
			m = split(substr(order[s], 2), shas, " ")
			for (j = 1; j <= m; j++)
				printf "#   sha %s  first=%s  last=%s\n", shas[j], first[s, shas[j]], last[s, shas[j]]
			printf "#   đoạn SHA liên tiếp (%d, >2 nghĩa là xen kẽ):%s\n", seg[s], segs[s]
		}
		mis = 0
		for (k = 0; k <= maxtk; k++) {
			if (((k, "be") in tsha) && ((k, "fe") in tsha) && tsha[k, "be"] != tsha[k, "fe"]) {
				if (!mis) mf = k; mis++; ml = k
			}
		}
		if (mis) printf "# be≠fe SHA: %d tick (tick %d → %d, ~%ds)\n", mis, mf, ml, ml - mf + 1
		else print "# be≠fe SHA: 0 tick"
	}'
}

STOP=0
trap 'STOP=1' INT TERM

echo ">> ghi $OUT (bodies: $BODIES). Ctrl+C để dừng." >&2
now_us() {
	echo "${EPOCHREALTIME//[!0-9]/}"
}
start_us="$(now_us)"
tick=0
while [[ "$STOP" -eq 0 ]]; do
	tick_once "$tick" &
	tick=$((tick + 1))
	if [[ "$DURATION" -gt 0 && "$tick" -ge "$DURATION" ]]; then
		break
	fi
	# Ngủ tới mốc start + tick giây (không cộng dồn độ trễ).
	wait_us=$((start_us + tick * 1000000 - $(now_us)))
	if [[ "$wait_us" -gt 0 ]]; then
		sleep "$((wait_us / 1000000)).$(printf '%06d' $((wait_us % 1000000)))"
	fi
done

# Chờ các tick đang bay (chúng bỏ qua SIGINT, xem tick_once) ghi xong dòng cuối.
wait
{
	echo "# m2-poll stop $(date -u +%Y-%m-%dT%H:%M:%SZ) ticks=$tick"
	summarize
} | tee -a "$OUT"
echo ">> bodies non-200: $(wc -l <"$BODIES") dòng trong $BODIES" >&2
exit 0

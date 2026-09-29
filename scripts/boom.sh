#!/usr/bin/env bash
# D22 — trigger THẬT alert "5xx rate": gọi `/boom` của be production tối đa 1 lần/giây
# (tuần tự — request chậm hơn 1 giây thì lần sau đi ngay, không dồn) trong DURATION giây
# rồi TỰ DỪNG. Kế hoạch: notes/d22-prep.md Pha B. Lần chạy 29/09 (bản cũ, curl + nghỉ 1 s):
# 197 request / 480 s.
#
# Tác động môi trường thật (sinh 5xx trên production, bắn alert Sev1 + email) → chỉ chạy
# khi người dùng đã duyệt trong phiên (CLAUDE.md "Tốn tiền = hỏi trước"). Máy chạy phải
# nằm trong whitelist (M6) — nếu không mọi dòng là 403 và alert không bao giờ bắn.
#
# Dùng:
#   scripts/boom.sh --be-url https://app-vsf-xxx.azurewebsites.net [--duration 480] [--out FILE]
# Dừng sớm: Ctrl+C.
#
# Vì sao 480 giây: alert cần > 5% 5xx VÀ ≥ 20 request trong cửa sổ 10 phút, đánh giá 5 phút/
# lần, log về workspace trễ 2–5 phút → 8 phút gọi liên tục phủ trọn ít nhất một lần đánh giá.
#
# Log thô (TSV, UTC): ts_utc  http_code  trace_id (header X-Trace-Id của be)
# — trace_id để truy vết alert → request (runbook bước 2–3).

set -uo pipefail
export LC_ALL=C

BE_URL=""
DURATION=480
OUT="evidence/raw/d22-boom-$(date -u +%Y%m%d-%H%M%S).tsv"

usage() {
	sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--be-url)
		BE_URL="${2%/}"
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

if [[ -z "$BE_URL" ]]; then
	echo "!! thiếu --be-url" >&2
	usage 2
fi
if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || ((DURATION < 1 || DURATION > 900)); then
	# Chặn trên 15 phút: quên dừng = alert treo + log tăng (notes/d22-prep.md bẫy T3).
	echo "!! --duration phải là số giây 1–900" >&2
	exit 2
fi

mkdir -p "$(dirname "$OUT")"
printf 'ts_utc\thttp_code\ttrace_id\n' >"$OUT"

total=0
errors=0
summary() {
	echo "# $(date -u +%FT%TZ) dừng — $total request, $errors 5xx" | tee -a "$OUT"
}
trap 'summary; exit 130' INT TERM

echo "# $(date -u +%FT%TZ) bắt đầu — $BE_URL/boom mỗi giây trong ${DURATION}s → $OUT" | tee -a "$OUT"
end=$((SECONDS + DURATION))
while ((SECONDS < end)); do
	tick=$((SECONDS + 1))
	# -4: whitelist chỉ có IPv4 (M6). -D -: lấy header X-Trace-Id cùng lượt.
	resp=$(curl -4 -s -o /dev/null -D - --max-time 5 -w '%{http_code}' "$BE_URL/boom" 2>/dev/null)
	code="${resp: -3}"
	trace_id=$(grep -i '^x-trace-id:' <<<"$resp" | tr -d '\r' | awk '{print $2}')
	printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$code" "${trace_id:-}" >>"$OUT"
	total=$((total + 1))
	[[ "$code" =~ ^5 ]] && errors=$((errors + 1))
	((total % 30 == 0)) && echo "  … $total request, $errors 5xx (mã gần nhất $code)"
	# Chỉ nghỉ phần còn lại của giây này: curl ~1,5 s (đo 29/09) thì đi tiếp ngay.
	while ((SECONDS < tick)); do sleep 0.2; done
done
summary

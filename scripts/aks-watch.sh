#!/usr/bin/env bash
# AKS (phần advanced) — theo dõi autoscale: mỗi INTERVAL giây ghi một dòng số pod `be`
# (HPA), CPU so với request, số node (cluster autoscaler) và pod chưa chạy. Để đối chiếu
# timeline 1 → 2 → 1 với log tải (scripts/load.sh) cùng đồng hồ UTC — vai trò của
# scripts/d19-watch.sh ở bài chính.
#
# CHỈ ĐỌC: chỉ `kubectl get`, không lệnh ghi nào, không phát sinh chi phí. Cần
# `make aks-credentials` sẵn.
#
# Dùng:
#   scripts/aks-watch.sh [--namespace opsboard] [--interval 15] [--out evidence/raw/aks-watch-....log]
# Dừng: Ctrl+C (hoặc SIGTERM).
#
# Cột log (TSV, UTC):
#   ts_utc  be_ready  be_desired  hpa_cpu_pct  nodes_ready  nodes_total  pending_pods  fe_ready

set -uo pipefail
export LC_ALL=C

NS="opsboard"
INTERVAL=15
OUT=""

usage() {
	sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	if [[ "$1" == --* && "$1" != "--help" && $# -lt 2 ]]; then
		echo "!! $1 thiếu giá trị" >&2
		usage 2
	fi
	case "$1" in
	--namespace)
		NS="$2"
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

if ! [[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -ge 5 ]]; then
	echo "!! --interval phải là số nguyên ≥ 5" >&2
	usage 2
fi

cd "$(dirname "$0")/.." || exit 2
if [[ -n "$OUT" ]]; then
	mkdir -p "$(dirname "$OUT")"
	exec > >(tee -a "$OUT") 2>&1
fi

trap 'echo "# dừng $(date -u +%Y-%m-%dT%H:%M:%SZ)"; exit 0' INT TERM

printf '# aks-watch namespace=%s interval=%ss bắt đầu %s\n' "$NS" "$INTERVAL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'ts_utc\tbe_ready\tbe_desired\thpa_cpu_pct\tnodes_ready\tnodes_total\tpending_pods\tfe_ready\n'

while true; do
	ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	# Một lệnh hỏng (API server chậm) ghi "?" cho ô đó, không giết vòng lặp.
	be_ready="$(kubectl -n "$NS" get deployment be -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo '?')"
	be_desired="$(kubectl -n "$NS" get deployment be -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '?')"
	hpa_cpu="$(kubectl -n "$NS" get hpa be -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || echo '?')"
	fe_ready="$(kubectl -n "$NS" get deployment fe -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo '?')"
	nodes="$(kubectl get nodes --no-headers 2>/dev/null)"
	if [[ -n "$nodes" ]]; then
		nodes_total="$(wc -l <<<"$nodes")"
		nodes_ready="$(awk '$2 == "Ready"' <<<"$nodes" | wc -l)"
	else
		nodes_total='?'
		nodes_ready='?'
	fi
	pending="$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)"
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ts" "${be_ready:-0}" "${be_desired:-?}" "${hpa_cpu:-?}" \
		"$nodes_ready" "$nodes_total" "$pending" "${fe_ready:-0}"
	sleep "$INTERVAL"
done

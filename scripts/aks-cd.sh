#!/bin/sh
# AKS (phần advanced) — phần chạy BÊN TRONG cluster của .github/workflows/cd-aks.yml.
# Workflow gửi file này lên bằng `az aks command invoke --file` rồi gọi `sh aks-cd.sh`;
# không chạy tay từ máy (chạy tay thì dùng thẳng kubectl).
#
# Việc của CD trên AKS, đúng một việc: đổi TAG image của hai Deployment. Mọi thứ khác
# của manifest do `make aks-deploy` sở hữu — cùng phân chia với App Service (Terraform sở
# hữu Web App, CD sở hữu tag image).
#
# Thứ tự `be` trước `fe` như swap slot ở cd.yml. Kiểm sau rollout bằng curl TỪ CHÍNH
# command pod này tới hai Service trong cluster — CD không cần quyền `pods/exec` (exec
# vào pod `be` là đọc được DB_PASSWORD trong env; review 12/10 #4). NetworkPolicy của `be`
# cho phép namespace `aks-command` chỉ vì bước này (k8s/base/networkpolicy.yaml).
#
# Rollback: đặt lại ĐÚNG image đã ghi nhớ trước khi đổi, và chỉ cho Deployment mà lần
# chạy này đã đổi. Không dùng `rollout undo`: undo lùi về "revision trước", mà revision
# trước không chắc là bản vừa chạy — `be` kẹt giữa chừng thì `fe` chưa đổi gì vẫn bị hạ
# cấp, và deploy lại đúng SHA đang chạy thì undo lùi về một bản cũ hơn (review 12/10 #2).
#
# Dùng: sh aks-cd.sh <namespace> <sha-deploy> [<sha-mong-đợi>]
#   <sha-mong-đợi> khác <sha-deploy> chỉ để cố ý làm bước kiểm thất bại (thử rollback).
#
# sh thuần, không sed/jq/awk: command pod chỉ có kubectl, curl và lệnh dựng sẵn của sh (đo 12/10).

set -eu

NS="$1"
SHA="$2"
EXPECT="${3:-$2}"

PREV_BE=""
PREV_FE=""
CHANGED=""

image_of() {
	kubectl -n "$NS" get deployment "$1" -o jsonpath='{.spec.template.spec.containers[0].image}'
}

rollback() {
	echo "!! $1"
	# fe trước rồi be — ngược thứ tự deploy, như bước Rollback của cd.yml.
	for d in fe be; do
		case " $CHANGED " in
		*" $d "*)
			if [ "$d" = "be" ]; then prev="$PREV_BE"; else prev="$PREV_FE"; fi
			echo "!! rollback $d ve $prev"
			kubectl -n "$NS" set image "deployment/$d" "$d=$prev" || true
			kubectl -n "$NS" rollout status "deployment/$d" --timeout=300s || true
			;;
		esac
	done
	if [ -z "$CHANGED" ]; then
		echo "RESULT=failed_nothing_changed"
	else
		echo "RESULT=rolled_back"
	fi
	exit 1
}

PREV_BE="$(image_of be)"
PREV_FE="$(image_of fe)"

for d in be fe; do
	if [ "$d" = "be" ]; then current="$PREV_BE"; else current="$PREV_FE"; fi
	target="${current%:*}:$SHA"
	echo ">> $d: $current -> $target"
	if [ "$current" != "$target" ]; then
		kubectl -n "$NS" set image "deployment/$d" "$d=$target"
		CHANGED="$CHANGED $d"
	fi
	kubectl -n "$NS" rollout status "deployment/$d" --timeout=300s || rollback "rollout $d khong xong trong 300s"
done

# In "<mã HTTP> <sha>" của một URL; sha rỗng nếu body không có trường "sha".
# Chỉ dùng phép cắt chuỗi của sh: command pod KHÔNG có sed/jq (đo 12/10: lần chạy đầu của
# bản dùng sed chết với "sed: not found" — ai-failure-log.md #51).
NL='
'
probe() {
	body="$(curl -s -m 5 -w '\n%{http_code}' "$1" || true)"
	code="${body##*"$NL"}"
	json="${body%"$NL"*}"
	rest="${json#*\"sha\":\"}"
	if [ "$rest" = "$json" ]; then
		sha=""
	else
		sha="${rest%%\"*}"
	fi
	printf '%s %s' "$code" "$sha"
}

# N=5 lần cách nhau 5 giây, như bước "Kiểm tra production" của cd.yml.
i=1
while [ "$i" -le 5 ]; do
	fe="$(probe "http://fe.$NS.svc/api/version")"
	be="$(probe "http://be.$NS.svc:8080/version")"
	# /api/health của fe gọi be /health và trả 200 chỉ khi be trả 200 — đúng đường request thật đi.
	health="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "http://fe.$NS.svc/api/health" || true)"
	echo "lan $i: fe [$fe] | be [$be] | fe->be /health $health | mong doi $EXPECT"
	if [ "$fe" != "200 $EXPECT" ] || [ "$be" != "200 $EXPECT" ] || [ "$health" != "200" ]; then
		rollback "kiem tra lan $i that bai"
	fi
	i=$((i + 1))
	sleep 5
done

echo "RESULT=deployed"

#!/usr/bin/env bash
# Gom bằng chứng M3 + M4 của D12 trong một lần chạy.
#
# CHỈ ĐỌC, trừ đúng một ngoại lệ: POST /items tạo một bản ghi test (đó chính là
# bằng chứng #2 của M3). Script KHÔNG apply, KHÔNG restart, KHÔNG sửa cấu hình
# Azure, nên không tự phát sinh chi phí — nhưng nó đòi môi trường đang bật.
#
# Dùng:  bash scripts/d12-verify.sh
# Kết quả in ra màn hình và lưu vào evidence/raw/d12-verify-<ngày>-<giờ>.log
#
# Những gì script KHÔNG làm được, bạn phải tự làm (xem notes/d12-prep.md):
#   - ảnh Portal: Environment variables 2 slot, Log stream, MySQL Networking
#   - M5: gỡ/trả role bằng terraform apply + az webapp restart
#   - chứng minh ngược AcrPull của M1

set -euo pipefail

TF=(terraform -chdir=infra/app)
RG="rg-vsf-dev"
STAMP="$(date +%Y-%m-%d-%H%M)"
LOG="evidence/raw/d12-verify-${STAMP}.log"

# Chạy một lệnh, in tiêu đề rồi in output. Không để lệnh lỗi làm chết cả script:
# thiếu một ô bằng chứng vẫn hơn là mất toàn bộ các ô sau.
step() {
	local title="$1"
	shift
	echo
	echo "=============================================================="
	echo "== $title"
	echo "== \$ $*"
	echo "=============================================================="
	"$@" 2>&1 || echo "!! LỆNH LỖI (exit $?) — ghi lại nguyên trạng, đừng bỏ qua"
}

# Dừng sớm với thông báo đọc được, thay vì để terraform/az ném lỗi thô.
preflight() {
	if [[ ! -d infra/app/.terraform ]]; then
		echo "!! Chưa init backend ở thư mục này." >&2
		echo "   Chạy trước:  make tf-init" >&2
		echo "   (make up cũng tự init, nếu bạn chưa dựng môi trường thì chạy make up)" >&2
		exit 1
	fi

	if ! az group show -n "$RG" >/dev/null 2>&1; then
		echo "!! Resource group $RG không tồn tại — môi trường đang TẮT." >&2
		echo "   Script này chỉ đo được khi môi trường bật. Chạy 'make up' trước" >&2
		echo "   (tốn tiền, ~25 phút, tự gõ yes — xem notes/d12-prep.md bước 3)." >&2
		exit 1
	fi
}

main() {
	echo "D12 verify — $(date '+%F %T %z')"
	echo "Thư mục: $(pwd)"
	echo "Commit:  $(git rev-parse --short HEAD)"

	# --- tra tên resource từ Terraform output, không hardcode suffix ---
	local url app mysql acr kv mi_principal
	url="$("${TF[@]}" output -raw app_url)"
	app="$(echo "$url" | sed 's|https://||; s|\..*||')"
	mysql="$("${TF[@]}" output -raw mysql_fqdn | sed 's|\..*||')"
	acr="$("${TF[@]}" output -raw acr_name)"
	kv="$("${TF[@]}" output -raw key_vault_name)"
	mi_principal="$("${TF[@]}" output -raw app_identity_principal_id)"

	echo
	echo "app=$app  mysql=$mysql  acr=$acr  kv=$kv"

	# ================= M3 =================
	step "M3 ô1 — /health" \
		curl -s -w $'\n<<HTTP %{http_code}>>\n' "$url/health"

	local ts
	ts="$(date +%H%M%S)"
	step "M3 ô2 — POST /items (bản ghi test d12-check-$ts)" \
		curl -s -w $'\n<<HTTP %{http_code}>>\n' -X POST "$url/items" \
		-H 'content-type: application/json' -d "{\"name\":\"d12-check-$ts\"}"

	step "M3 ô3 — GET /items (phải thấy d12-check-$ts)" \
		curl -s -w $'\n<<HTTP %{http_code}>>\n' "$url/items"

	step "M3 ô5-8 — firewall MySQL (chỉ được có rule app-outbound-*)" \
		az mysql flexible-server firewall-rule list -g "$RG" -n "$mysql" -o table

	step "M3 ô5 — SỐ rule firewall" \
		az mysql flexible-server firewall-rule list -g "$RG" -n "$mysql" --query "length(@)"

	step "M3 ô5 — SỐ possible outbound IP (phải BẰNG số trên)" \
		"${TF[@]}" output -raw app_possible_outbound_ip_count

	# ================= M4 =================
	step "M4 ô1,3 — app settings production (mong đợi đúng 7 khoá)" \
		az webapp config appsettings list -g "$RG" -n "$app" -o table

	step "M4 ô2 — app settings slot staging (phải giống production)" \
		az webapp config appsettings list -g "$RG" -n "$app" --slot staging -o table

	step "M4 ô3 — DB_PASSWORD phải là tham chiếu KHÔNG kèm version" \
		az webapp config appsettings list -g "$RG" -n "$app" \
		--query "[?name=='DB_PASSWORD'].value" -o tsv

	step "M4 ô6 — connection strings (mong đợi rỗng)" \
		az webapp config connection-string list -g "$RG" -n "$app"

	step "M4 ô7 — ACR admin user (mong đợi false)" \
		az acr show -n "$acr" --query adminUserEnabled

	step "M4 ô8-9 — role của managed identity, --all để thấy cả role kế thừa" \
		az role assignment list --assignee "$mi_principal" --all \
		--query "[].{role:roleDefinitionName,scope:scope}" -o table

	# ================= M1 nhắc lại =================
	step "M1 — cờ pull bằng MI (az webapp config show trả null cho client id, phải đọc qua az resource show)" \
		az resource show -g "$RG" --resource-type Microsoft.Web/sites/config \
		--name "$app/web" \
		--query "properties.{mi:acrUseManagedIdentityCreds,clientId:acrUserManagedIdentityID,image:linuxFxVersion}"

	step "M1 — client id mong đợi" \
		"${TF[@]}" output -raw app_identity_client_id

	# ================= drift =================
	step "Trạng thái Key Vault reference sẽ KHÔNG hiện ở CLI — phải chụp Portal" \
		echo "Portal -> Web App -> Settings -> Environment variables -> DB_PASSWORD phải có nhãn 'Key vault Reference' + Resolved. Làm cho CẢ production và slot staging."

	echo
	echo "=============================================================="
	echo "Xong. Đọc lại log rồi chép số vào evidence/M3.md và evidence/M4.md."
	echo "Còn thiếu (tự làm): ảnh Portal, M5, chứng minh ngược AcrPull."
	echo "=============================================================="
}

preflight
mkdir -p evidence/raw
main 2>&1 | tee "$LOG"
echo
echo ">>> Log đã lưu: $LOG"

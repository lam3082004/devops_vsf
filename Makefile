.PHONY: fe-install fe-dev fe-lint fe-build db-up db-down db-logs run test test-db lint fmt check tf-init plan up down outputs check-empty

ENV_FILE := app/be/.env.local
DB_CONTAINER := d4-mysql

## Bật MySQL local (tạo container nếu chưa có), chờ tới khi healthy
db-up:
	@docker start $(DB_CONTAINER) 2>/dev/null || \
	docker run -d --name $(DB_CONTAINER) \
		-e MYSQL_ROOT_PASSWORD=devpass -e MYSQL_DATABASE=opsboard \
		-p 3307:3306 \
		--health-cmd="mysqladmin ping -h 127.0.0.1 -u root -pdevpass" \
		--health-interval=5s --health-timeout=3s --health-retries=10 \
		mysql:8.4
	@printf "cho MySQL healthy"
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(DB_CONTAINER))" = "healthy" ]; do \
		printf "."; sleep 2; \
	done; echo " OK"

## Tắt MySQL local (dữ liệu vẫn còn trong container)
db-down:
	@docker stop $(DB_CONTAINER) >/dev/null && echo "da dung $(DB_CONTAINER)"

db-logs:
	@docker logs --tail 30 $(DB_CONTAINER)

## Chạy app với biến từ app/be/.env.local
run:
	@test -f $(ENV_FILE) || { echo "thieu $(ENV_FILE) — chay: cp app/be/.env.example $(ENV_FILE)"; exit 1; }
	@set -a; . ./$(ENV_FILE); set +a; dotnet run --project app/be/OpsBoard.csproj

test:
	dotnet test app/be.Tests/OpsBoard.Tests.csproj

## Test đầy đủ kèm MySQL thật (make test vẫn skip phần DB)
test-db: db-up
	TEST_DB_HOST=127.0.0.1 TEST_DB_PORT=3307 TEST_DB_USER=root \
	TEST_DB_PASSWORD=devpass TEST_DB_NAME=opsboard \
	dotnet test app/be.Tests/OpsBoard.Tests.csproj

lint:
	dotnet format app/be/OpsBoard.csproj --verify-no-changes --severity warn

fmt:
	dotnet format app/be/OpsBoard.csproj

## Cổng kiểm tra trước khi commit — đúng những gì CI chạy cho code (be + fe)
check:
	dotnet format app/be/OpsBoard.csproj --verify-no-changes --severity warn && dotnet test app/be.Tests/OpsBoard.Tests.csproj
	npm --prefix app/fe run lint && npm --prefix app/fe run build

# ---------- Terraform: môi trường app trên Azure (từ D8) ----------
# Yêu cầu: `az login`. Subscription lấy từ az nếu chưa đặt ARM_SUBSCRIPTION_ID.
TF := terraform -chdir=infra/app
ifndef ARM_SUBSCRIPTION_ID
export ARM_SUBSCRIPTION_ID := $(shell az account show --query id -o tsv 2>/dev/null)
endif

tf-init:
	$(TF) init -backend-config=backend.hcl

## Xem trước thay đổi (không tốn tiền)
plan: tf-init
	$(TF) plan

## Dựng môi trường — APPLY 3 PHA (TỐN TIỀN, hỏi xác nhận từng pha)
## Lý do gốc (2 pha, notes/d8.md): firewall MySQL dùng for_each trên possible
## outbound IPs của `be`, giá trị "known after apply" cho tới khi Web App `be`
## đã có trong state — Terraform không tính được tập khoá của for_each lúc
## plan và từ chối (Invalid for_each argument).
## D16 thêm một cạnh known-after-apply nữa TRƯỚC `be`: be.ip_restriction dùng
## for_each trên fe.possible_outbound_ip_address_list (locals.tf:
## local.be_ip_rules, D16 Việc 2) để fe gọi được be. Cùng lý do, `fe` phải có
## trong state trước khi apply `be`. Ba pha theo đúng thứ tự phụ thuộc:
## fe → be → apply toàn bộ (lúc đó firewall MySQL mới tính được).
up: tf-init
	@if ! $(TF) state list 2>/dev/null | grep -qx 'azurerm_linux_web_app.fe'; then \
		echo ">>> pha 1/3: tao Web App fe de biet outbound IPs cho ip_restriction cua be"; \
		$(TF) apply -target=azurerm_linux_web_app.fe || exit 1; \
	else \
		echo ">>> Web App fe da co trong state, bo qua pha 1"; \
	fi
	@if ! $(TF) state list 2>/dev/null | grep -qx 'azurerm_linux_web_app.app'; then \
		echo ">>> pha 2/3: tao Web App be (va cac phu thuoc) de biet outbound IPs cho firewall MySQL"; \
		$(TF) apply -target=azurerm_linux_web_app.app || exit 1; \
	else \
		echo ">>> Web App be da co trong state, bo qua pha 2"; \
	fi
	@echo ">>> pha 3/3: apply toan bo"
	$(TF) apply

## Xoá môi trường app (giữ nguyên rg-vsf-bootstrap chứa state)
down: tf-init
	$(TF) destroy

## In URL, tên ACR, Key Vault... (đọc từ state, không gọi Azure)
outputs: tf-init
	$(TF) output

## Kỷ luật "không để qua đêm": sau `down`, rg-vsf-dev phải trống hoặc không còn.
## Không dùng $(TF) vì mục đích là kiểm tra NGOÀI state — lỡ state sai/thiếu
## resource thì lệnh này vẫn phát hiện được rác còn sót trên Azure thật.
check-empty:
	@echo ">>> resource con lai trong rg-vsf-dev (phai rong hoac RG khong ton tai):"
	@az resource list -g rg-vsf-dev -o table 2>/dev/null || echo "rg-vsf-dev khong ton tai — OK"

## Frontend (app/fe)
fe-install:
	npm --prefix app/fe ci

fe-dev:
	npm --prefix app/fe run dev

fe-lint:
	npm --prefix app/fe run lint

fe-build:
	npm --prefix app/fe run build

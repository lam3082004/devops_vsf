.PHONY: db-up db-down db-logs run test lint fmt check tf-init plan up down

ENV_FILE := app/.env.local
DB_CONTAINER := d4-mysql

## Bật MySQL local (tạo container nếu chưa có), chờ tới khi healthy
db-up:
	@docker start $(DB_CONTAINER) 2>/dev/null || \
	docker run -d --name $(DB_CONTAINER) \
		-e MYSQL_ROOT_PASSWORD=devpass -e MYSQL_DATABASE=nodereg \
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

## Chạy app với biến từ app/.env.local
run:
	@test -f $(ENV_FILE) || { echo "thieu $(ENV_FILE) — chay: cp app/.env.example $(ENV_FILE)"; exit 1; }
	@set -a; . ./$(ENV_FILE); set +a; cd app && cargo run

test:
	cd app && cargo test

lint:
	cd app && cargo clippy -- -D warnings

fmt:
	cd app && cargo fmt

## Cổng kiểm tra trước khi commit: format + lint + test
check:
	cd app && cargo fmt --check && cargo clippy -- -D warnings && cargo test

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

## Dựng môi trường — APPLY 2 PHA (TỐN TIỀN, hỏi xác nhận từng pha)
## Pha 1 chỉ chạy khi Web App chưa có trong state: firewall MySQL dùng for_each trên
## possible outbound IPs, giá trị này chưa biết trước khi Web App tồn tại.
## Lý do chọn cách này: Decision trong notes/d8.md.
up: tf-init
	@if ! $(TF) state list 2>/dev/null | grep -qx 'azurerm_linux_web_app.app'; then \
		echo ">>> pha 1/2: tao Web App (va cac phu thuoc) de biet outbound IPs"; \
		$(TF) apply -target=azurerm_linux_web_app.app || exit 1; \
	else \
		echo ">>> Web App da co trong state, bo qua pha 1"; \
	fi
	@echo ">>> pha 2/2: apply toan bo"
	$(TF) apply

## Xoá môi trường app (giữ nguyên rg-vsf-bootstrap chứa state)
down: tf-init
	$(TF) destroy

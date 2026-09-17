.PHONY: db-up db-down db-logs run test lint fmt check

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

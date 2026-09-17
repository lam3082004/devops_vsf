# D4 — Viết app (Rust, chủ đề Node registry) — 2026-09-16

Nhật ký: `notes/d4.md` · Source: `app/`

## App
`node-registry` — Rust 1.95, axum + tokio + sqlx (MySQL, TLS rustls). Bảng `nodes`: node tự đăng ký tên, địa chỉ, vai trò, lần cuối thấy.

## 6 endpoint theo yêu cầu đề bài

| Endpoint | Hành vi | Phục vụ |
|---|---|---|
| `GET /health` | ping DB, timeout 1s → 200 / **503** | warm-up swap (M2) |
| `GET /version` | SHA nhúng lúc biên dịch qua `option_env!` | M2 |
| `GET /load?seconds=n` | đốt CPU trong `spawn_blocking`, giới hạn 1..=`LOAD_MAX_SECONDS` | M7 |
| `GET\|POST /items` | bảng `nodes`; POST trùng tên → `ON DUPLICATE KEY UPDATE last_seen_at` | M3 |
| `GET /boom` | 500, tiến trình vẫn sống | M11 |
| path lạ | 404 JSON | |

## 7 kịch bản kiểm thử — tất cả đạt

| # | Kịch bản | Kết quả |
|---|---|---|
| 1 | Thiếu biến bắt buộc | log `config_error` nêu **tên biến** (không in giá trị), exit code **1** |
| 2 | `DB_PASSWORD='@Microsoft.KeyVault(...)'` | lỗi riêng `UnresolvedKeyVault` → **điều kiện để M5 gãy quan sát được** |
| 3 | Đủ biến + MySQL chạy | `/health` 200 · POST 201 · GET trả bản ghi · name rỗng/201 ký tự → 400 |
| 4 | `/boom` | 500 rồi request sau vẫn 200 |
| 5 | Tắt MySQL | `/health` **503**; bật lại → **200 tự hồi phục**, không cần restart app |
| 6 | `/load` | thiếu/`abc`/`0`/`61` → 400 · `seconds=2` → 200 sau 2.0005s |
| 7 | SIGTERM khi đang xử lý request | `shutdown_started` → request `/load 5s` vẫn trả **200** → `shutdown_complete` |

## Kiểm chứng đáng giá nhất
Gọi `/version` **trong lúc** `/load` đang đốt CPU → 200 sau **0.0006 giây**. Runtime async không bị chặn nhờ `spawn_blocking`. Nếu đốt CPU thẳng trong handler thì `/health` timeout và App Service coi instance là hỏng — mất cả M2 lẫn M7.

## Chất lượng
`cargo test` **9 pass** (2 config · 3 validate · 4 HTTP) · `cargo clippy -D warnings` sạch · `cargo fmt --check` sạch.

## 2 lỗi đã gặp
1. **Log có 2 key `level` trùng nhau** (tự đặt `level="fatal"` đè lên field của subscriber) → KQL `parse_json` chỉ giữ 1 → đổi tên thành `event`.
2. **`/version` trả `dev` dù build với `GIT_SHA`** — Cargo không rebuild khi chỉ biến môi trường đổi → thêm `build.rs` với `cargo::rerun-if-env-changed=GIT_SHA`. Không sửa thì **bằng chứng M2 sẽ sai**.

# D4 — Viết app

**Cần:** — · **Chi phí:** 0 · **Nhật ký:** `notes/d4.md` · **AI-OFF:** tự viết code

## Mục tiêu

Một app web nhỏ có đủ 6 "nút bấm để demo" hạ tầng, cấu hình qua biến môi trường, log JSON, tắt êm, và **gãy rõ ràng khi cấu hình sai**. Chủ đề app tuỳ bạn (sổ ghi chú, danh sách việc, kho sách…) — bảng `items` là đủ.

## 1. Chọn ngôn ngữ (ghi Decision)

| Tiêu chí | Go | Python (FastAPI/Flask) | Node (Express/Fastify) |
|---|---|---|---|
| Image nhỏ, 0 CVE (M9) | Dễ nhất: binary tĩnh + distroless | Khó hơn: cần runtime + thư viện hệ thống | Trung bình |
| Nhúng SHA lúc build | Cờ linker | Biến môi trường lúc build / file | Biến môi trường lúc build / file |
| Đốt CPU cho `/load` | Vòng lặp thật | Bị GIL giới hạn 1 core (P0V3 có 1 vCPU → vẫn đủ) | Chặn event loop — phải cẩn thận |
| Bạn đã quen | ? | ? | ? |

Chọn thứ bạn **giải thích được**. Ghi lý do vào `notes/d4.md`.

## 2. Cấu trúc repo đề xuất

```
app/            source + test
infra/          Terraform (từ D7)
.github/        workflows, PR template (từ D6)
scripts/        poll-version, load test (D18, D19)
docs/           plans, guides, architecture
evidence/       M1.md … M11.md
notes/          nhật ký học
```

## 3. Cấu hình (biến môi trường)

| Biến | Bắt buộc | Ví dụ | Kiểm tra lúc khởi động |
|---|---|---|---|
| `PORT` | không (mặc định 8080) | 8080 | là số |
| `DB_HOST` | có | `…mysql.database.azure.com` | không rỗng |
| `DB_PORT` | không (3306) | 3306 | là số |
| `DB_NAME` | có | `appdb` | không rỗng |
| `DB_USER` | có | `appadmin` | không rỗng |
| `DB_PASSWORD` | có | (từ Key Vault) | không rỗng **và không bắt đầu bằng `@Microsoft.KeyVault(`** |
| `DB_TLS` | không (true) | true | true/false |
| `LOAD_MAX_SECONDS` | không (60) | 60 | 1–300 |

**Fail fast:** thiếu hoặc sai → in một dòng log JSON level `fatal` nêu **tên biến** (không in giá trị) → thoát mã khác 0.

## 4. Đặc tả endpoint

| Endpoint | Hành vi | Mã trả về |
|---|---|---|
| `GET /health` | Ping DB với timeout ~1s | 200 `{"status":"ok","db":"ok"}` · 503 `{"status":"degraded","db":"error"}` |
| `GET /version` | Trả SHA được **nhúng lúc build** (không đọc từ env lúc chạy) | 200 `{"sha":"<40 ký tự>","built_at":"…"}` · build local không truyền SHA → `"dev"` |
| `GET /load?seconds=n` | Đốt CPU đúng n giây rồi trả kết quả | 200 `{"burned_seconds":n}` · 400 nếu n thiếu, không phải số, < 1 hoặc > `LOAD_MAX_SECONDS` |
| `GET /items` | Liệt kê tối đa 100 bản ghi mới nhất | 200 mảng JSON |
| `POST /items` | Body `{"name":"…"}` (1–200 ký tự) → chèn | 201 bản ghi vừa tạo · 400 body sai · 503 DB lỗi |
| `GET /boom` | Ném exception **được middleware bắt** → log error kèm stack trong một trường JSON | 500 `{"error":"boom"}` — process **không chết** |
| mọi path khác | | 404 JSON |

Bảng `items`: `id` tự tăng khoá chính · `name` chuỗi ≤ 200 không rỗng · `created_at` thời điểm tạo, mặc định lúc chèn. Tạo bảng **lúc khởi động, idempotent** ("nếu chưa tồn tại").

## 5. Log JSON

- Mỗi request đúng **một dòng** ra stdout: `ts` (RFC3339, UTC) · `level` · `msg` · `method` · `path` · `status` · `duration_ms` · `request_id`.
- Sự kiện vòng đời: `startup` (kèm sha, port), `db_connected`, `shutdown_started`, `shutdown_complete`.
- Lỗi: `level":"error"` + `error` + `stack` (stack là **một chuỗi**, không in nhiều dòng).
- **Không bao giờ** log mật khẩu, connection string, header Authorization.

## 6. Tắt êm
- Bắt SIGTERM/SIGINT → ngừng nhận kết nối mới → chờ request đang xử lý tối đa ~20s → đóng pool DB → thoát 0.
- Chạy app là **tiến trình chính** (không bọc qua shell script) để nhận được tín hiệu.

## 7. Test tối thiểu (chạy không cần MySQL thật)
- `/version` trả đúng SHA được nhúng (và `dev` khi không nhúng).
- `/load`: `seconds` = 0, 61, `abc`, thiếu → 400.
- `POST /items`: body rỗng, name 201 ký tự → 400.
- Cấu hình: `DB_PASSWORD` bắt đầu bằng `@Microsoft.KeyVault(` → lỗi cấu hình.
- `/boom` → 500 và app vẫn phục vụ request tiếp theo.

## 8. Chạy thử local
Cần một MySQL local (container MySQL 8 chính thức, D5 sẽ gom vào compose). Kiểm tra lần lượt bằng curl và ghi output vào note:
1. Thiếu `DB_HOST` → app thoát, log fatal nêu tên biến.
2. `DB_PASSWORD='@Microsoft.KeyVault(SecretUri=x)'` → app thoát.
3. Đủ biến → `/health` 200, POST rồi GET `/items`, `/boom` 500 rồi `/health` vẫn 200.
4. Tắt MySQL → `/health` 503, bật lại → 200 (có tự kết nối lại không?).
5. `/load?seconds=10` → quan sát CPU tăng.
6. Gửi SIGTERM trong lúc `/load?seconds=10` đang chạy → log shutdown, request đang dở có hoàn tất không?
7. Khởi động lại app 2 lần → không lỗi tạo bảng.

## Bẫy
- `/health` luôn 200 → swap sẽ chuyển traffic khi DB chưa sẵn sàng.
- `/health` quá nặng (truy vấn bảng lớn) → tự làm chậm app và làm health check fail.
- SHA đọc từ biến môi trường lúc chạy → slot setting có thể làm log M2 không đổi A→B.
- `/boom` làm sập process → App Service restart container, alert 5xx khó trigger ổn định.
- Log in nhiều dòng → Log Analytics tách thành nhiều bản ghi.

## Tự kiểm tra
1. Vì sao app nên thoát khi `DB_PASSWORD` là chuỗi `@Microsoft.KeyVault(...)`?
2. Liveness khác readiness thế nào, `/health` của bạn là loại nào?
3. Vì sao process chính trong container phải là app?

## Xong khi
- [ ] Decision ngôn ngữ · [ ] 6 endpoint đúng đặc tả · [ ] test pass · [ ] 7 kiểm tra local có output trong note

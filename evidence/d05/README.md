# D5 — Docker · Trivy · Cost Analysis — 2026-09-16 → 17

Nhật ký: `notes/d5.md` · Dockerfile: `app/Dockerfile` · Compose: `docker-compose.yml`

## So sánh 2 phương án base image

| | Phương án A | **Phương án B (đã chọn)** |
|---|---|---|
| Runtime base | `gcr.io/distroless/cc-debian12:nonroot` | **`scratch`** + target `x86_64-unknown-linux-musl` |
| Kích thước | 28.8 MB | **5.2 MB** |
| Build lần đầu | 8'35" | ~9' (thêm bước cài musl target) |
| CRITICAL / HIGH | 0 / 0 | **0 / 0** |
| MEDIUM / LOW | 15 / 15 | **0 / 0** |
| Còn lại nếu `--ignore-unfixed` | 0 | 0 |
| TLS tới MySQL | có | **có** (đã kiểm chứng `DB_TLS=true` → `/health` 200) |

**Nguồn 30 CVE của phương án A:** `libc6` 19 · `libssl3` 7 · `libstdc++6` · `libgcc-s1` · `libgomp1` · `gcc-12-base` — **không cái nào đến từ code Rust**, và **tất cả đều chưa có bản vá** nên không thể sửa bằng cách cập nhật package.

**Kết luận cho M9:** chọn `scratch` + musl thì đạt **0 CVE thật sự**, không phụ thuộc cờ `--ignore-unfixed`. Nhờ đó câu hỏi Q4 gửi mentor trở thành không bắt buộc.

## Cấu hình Dockerfile (không hardcode)
- Base images khai báo bằng `ARG RUST_IMAGE` / `ARG RUNTIME_IMAGE` / `ARG RUST_TARGET` → CI hoặc registry mirror thay được mà không sửa file
- Multi-stage + cache layer dependencies (build binary rỗng trước)
- `ARG GIT_SHA` → `ENV` → nhúng vào binary
- `USER 65532:65532` (scratch không có `/etc/passwd` nên dùng uid số)
- `ENTRYPOINT` dạng exec → binary là **PID 1**, nhận SIGTERM

## Kiểm chứng container

| Kiểm tra | Kết quả |
|---|---|
| `/version` | `{"sha":"a6dbfec"}` — đúng SHA truyền qua `--build-arg` |
| `/health` với `DB_TLS=true` | **200** — rustls hoạt động trong binary tĩnh |
| `POST /items` | 201 |
| User trong container | uid **65532**, không phải root |
| PID 1 | `/app/node-registry` |
| `docker exec ... id` | thất bại — không có shell (đúng thiết kế) |
| `docker stop` | `shutdown_started` → request `/load 5s` đang dở trả **200** → `shutdown_complete`, tổng 4s |

## Sự cố gặp phải
Docker Hub `TLS handshake timeout` 2 lần khi kéo `rust:1.95-slim` và `docker/dockerfile:1`. Cách xử lý: bỏ dòng `# syntax=` (không cần image phụ) và build với `--pull=false` để dùng cache cục bộ. Trong CI cần tính tới việc registry chập chờn → retry hoặc dùng mirror.

## Chi phí thật (Cost Analysis, 2026-09-17)

Scope: billing account `LAM BUI TUNG` · kỳ **Sep 2026** · Actual cost **$0.51**

| Dịch vụ | Thật | Ước tính của mình | Chênh |
|---|---|---|---|
| Azure App Service | **$0.41** | ~$0.44 (D2 2h45 P0V3+B1, D3 2h20 P0V3) | thấp hơn 7% |
| Azure Database for MySQL | **$0.10** | ~$0.13 | thấp hơn 23% |
| Bandwidth | **$0.00** | 0 | khớp |
| **Tổng** | **$0.51** | ~$0.58 | thấp hơn ~12% |

Credit còn lại: **$199.64** / $200.

Nhận xét:
- Ước tính bằng tay (giờ chạy × giá/giờ từ Retail API) **sai dưới 15%** — đủ tốt để dự toán trong cost report M7.
- Số thật thấp hơn vì tính theo giây/phút thực tế, không phải trọn giờ; và phần D3 (kết thúc 16:07 ngày 16) có thể chưa lên hết do **độ trễ 8–24h**.
- Biểu đồ Accumulated chỉ có **một cột duy nhất ngày 16/09**, các ngày sau bằng 0 → bằng chứng trực quan cho biện pháp tiết kiệm "destroy sau mỗi buổi" trong M7.
- **Forecast unavailable** vì mới có 1 ngày dữ liệu.

Ảnh: `screenshots/cost-analysis-20260917-0940.png`

*(API `Microsoft.CostManagement/query` trả 429 Too Many Requests — Azure giới hạn tần suất truy vấn; lấy số từ Portal.)*

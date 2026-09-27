# Ảnh Portal còn nợ — gộp vào một phiên có môi trường bật

Trạng thái: **8 ảnh chưa chụp** (6 cũ + 2 của M7/D19) · Cập nhật 2026-09-27 (D19)
Quy ước tên + luật che: `evidence/screenshots-convention.md`

> **Không chặn bài nào.** Cả M3, M4, M5, M6 đều đã **ĐẠT** bằng log thô + JSON; ảnh Portal
> là phần bổ sung ("mục 3.5 của guide, **không** nằm trong Xong khi" — `evidence/M6.md`).
> Gom vào đây để không phải bật môi trường nhiều lần.

## Làm cùng lúc với M8 lần 2 của D15 — đừng bật riêng

D15 mục 5 bắt chạy lại `make down` → `make up` sau các thay đổi tuần 3 (ACR + Key Vault +
IP whitelist) để cập nhật `evidence/M8.md` lần 2. Phiên đó **bắt buộc** phải có môi trường
bật ~45 phút.

Bật riêng chỉ để chụp ảnh là trả ~25 phút `make up` + tiền cho một việc mà phiên D15 đằng
nào cũng phải làm. **Chụp trong cửa sổ đó.** Chi tiết: `notes/d15-prep.md` bước 4.

## Cạm bẫy phải biết trước: suffix sẽ KHÁC

`infra/app/main.tf` sinh `random_string.suffix` mới **mỗi lần dựng lại**. Các lần đã đo:

| Môi trường | Suffix | Dùng ở |
|---|---|---|
| D10 (M8 lần 1) | `muv1nf` | `evidence/M8.md` |
| D12 | `j124ze` | `evidence/M3.md`, `M4.md`, `M5.md` |
| D13 | `p0hef1` | `evidence/M6.md` |
| **lần tới** | **sẽ là cái thứ tư** | các ảnh dưới đây |

Nghĩa là tên resource trong ảnh sẽ **không khớp** tên trong chính file evidence mà ảnh đó
minh hoạ. Đây là hành vi đúng, không phải lỗi — nhưng người chấm nhìn vào sẽ thắc mắc.

**Bắt buộc:** khi dán ảnh vào `evidence/M*.md`, ghi ngay dưới ảnh một dòng dạng
*"Ảnh chụp trên môi trường dựng lại ngày ..., suffix `xxxxxx` — khác suffix `j124ze` ở bảng
trên vì suffix sinh ngẫu nhiên mỗi lần `make up`."*

Lấy suffix thật ngay sau khi `make up` xong:

```bash
terraform -chdir=infra/app output -raw name_suffix
```

## M7 (D19) — 2 ảnh autoscale · ⚠️ chụp TRƯỚC `make down`

Khác 6 ảnh bên dưới: hai ảnh này **không chụp lại được** sau khi xoá plan — `make down` xoá
`asp-vsf-dev` cùng metric và Run history của autoscale setting. Môi trường `jcip0s` đang bật (27/09),
chụp ngay trong phiên D19/D20. Thiếu ảnh thì M7 vẫn có log thô (`evidence/M7.md` mục 2), nhưng guide
ghi "screenshot 1→2 và 2→1" trong "Xong khi".

Đặt vào `evidence/d19/screenshots/`. Chỉnh khung giờ Portal sang **UTC** hoặc ghi rõ múi giờ trong tên.

| # | Đường đi trong Portal | Trong ảnh PHẢI thấy | Tên file gợi ý |
|---|---|---|---|
| M7-1 | App Service Plan `asp-vsf-dev` → **Monitoring → Metrics** → `CPU Percentage` (Avg) + `Instance Count` nếu có, khung **2026-09-27 16:00–16:45Z** | CPU lên ~100% từ ~16:16, về ~10% từ ~16:24 | `m7-plan-cpu-metric-20260927.png` |
| M7-2 | App Service Plan → **Scale out (App Service plan)** → tab **Run history** (khung 1 ngày) | Sự kiện scale **out 1→2** (~16:20:42Z) và **in 2→1** (~16:32:37Z) | `m7-autoscale-run-history-20260927.png` |

## Sáu ảnh

Đặt vào `evidence/screenshots/m06/` (3 ảnh đầu) và `evidence/screenshots/d12/` (3 ảnh sau).
Tên file theo mẫu `<nội dung>-<YYYYMMDD-HHMM>.png`.

### Nhóm M6 — access restriction (3 ảnh, `evidence/M6.md` mục "Ảnh Portal")

| # | Đường đi trong Portal | Trong ảnh PHẢI thấy | Tên file gợi ý |
|---|---|---|---|
| 1 | Web App `app-vsf-<suffix>` → **Networking** → **Access restrictions**, tab *Site* | Danh sách luật Allow + dòng **Unmatched rule action: Deny** | `m6-access-restrictions-site-<ts>.png` |
| 2 | Cùng chỗ, chọn slot **staging** (Deployment slots → staging → Networking) | Như trên, nhưng của slot | `m6-access-restrictions-slot-<ts>.png` |
| 3 | Cùng trang, tab **Advanced tool site** (SCM) — chụp cho **cả** site chính và slot | Tick *Use main site rules* **VÀ** **Unmatched rule action: Deny** | `m6-scm-use-main-deny-<ts>.png` |

> **Ảnh 3 là ảnh quan trọng nhất của cả nhóm.** Đúng chỗ này là lỗ hổng D13 đã bắt được:
> `scm_use_main_ip_restriction = true` làm tick *Use main site rules* sáng lên, nhưng
> *Unmatched rule action* vẫn là **Allow** → Kudu vẫn vào được. Ảnh chỉ có giá trị nếu
> **thấy được cả hai** thứ đó trong cùng một khung. Chỉ chụp cái tick là chụp đúng thứ đã
> đánh lừa mình lần trước. Xem `evidence/M6.md` mục "Cái bẫy thật của bài này".

### Nhóm D12 (3 ảnh)

| # | Đường đi trong Portal | Trong ảnh PHẢI thấy | Đi kèm file | Tên file gợi ý |
|---|---|---|---|---|
| 4 | Web App → **Environment variables** → *App settings*, và lặp lại cho slot **staging** | `DB_PASSWORD` hiện là `@Microsoft.KeyVault(SecretUri=…)` với nhãn **Key vault Reference** trạng thái **Resolved**; `DOCKER_REGISTRY_SERVER_PASSWORD` **không** tồn tại | `evidence/M4.md` | `m4-env-vars-production-<ts>.png`, `m4-env-vars-staging-<ts>.png` |
| 5 | Web App → **Log stream** | Dòng log của **đúng 2 request** vừa gọi (`POST /items` rồi `GET /items`), thấy được status code và `X-Trace-Id` | `evidence/M3.md` ô #4 (đang ghi **CHƯA CÓ**) | `m3-log-stream-2-requests-<ts>.png` |
| 6 | MySQL Flexible Server `mysql-vsf-<suffix>-sea` → **Networking** | Danh sách firewall rule + **"Allow public access from any Azure service" TẮT** | `evidence/M3.md` (bảng đối chiếu số firewall rule) | `m3-mysql-networking-<ts>.png` |

Ảnh #4 đã có bản D11 (`evidence/d11/screenshots/07-env-vars-production.png`, `08-…staging.png`)
dùng làm **lần đo thứ nhất**; lần này chụp lại trên môi trường mới để khớp với bảng của M4.

## Ảnh #5 cần chuẩn bị trước, không bấm là có

Log stream chỉ hiện log **phát sinh khi đang mở**. Trình tự:

1. Mở tab **Log stream**, đợi tới khi thấy dòng "Connected".
2. Sang terminal, gọi đúng 2 request (từ IP đã whitelist, nếu không sẽ 403):
   ```bash
   # output là app_url, đã kèm sẵn https:// — không có output tên app_default_hostname
   APP=$(terraform -chdir=infra/app output -raw app_url)
   curl -s -X POST "$APP/items" -H 'Content-Type: application/json' \
        -d '{"name":"d15-shot-'"$(date +%H%M%S)"'"}' -i | head -20
   curl -s "$APP/items" -i | head -20
   ```
3. Quay lại tab Log stream, chụp khi hai dòng còn trên màn hình.

Bật WARP là hỏng bước 2 (IP đổi sang dải Cloudflare → 403). Tắt trước:
`warp-cli disconnect`. Xem `known-issues.md` #11.

## Ảnh M5 — cân nhắc BỎ, đừng làm theo quán tính

`evidence/M5.md` ghi "thiếu ảnh Portal và dòng stdout của chính app". Nhưng M5 là bài
**app gãy khi mất quyền Key Vault**: muốn có ảnh thì phải diễn lại toàn bộ kịch bản —
`apply -var 'grant_app_keyvault_access=false'` → chờ RBAC → restart → chụp → apply lại →
restart. Khoảng 30–40 phút và làm site chết giữa chừng.

Bảng đo của M5 đã **điền đủ 12/12 ô** bằng kết quả thật, kèm nguyên khối JSON
`"status": "AccessToKeyVaultDenied"`. Đó là bằng chứng mạnh hơn ảnh.

**Đề xuất: bỏ ảnh M5**, ghi rõ lý do vào `evidence/M5.md` thay vì để treo mãi. Nếu vẫn
muốn làm thì đó là một phiên riêng, **không** nhét vào cửa sổ D15.

## Sau khi chụp xong

- [ ] Lưu ảnh **ngay** vào thư mục repo — ảnh gửi qua khung chat không tự lưu
      (`evidence/screenshots-convention.md` mục "Lưu ý").
- [ ] Che 2 octet cuối của IP nhà trong ảnh #1, #2, #3, #6.
- [ ] Dán link ảnh vào `evidence/M3.md` (ô #4 đang là **CHƯA CÓ**), `M4.md`, `M6.md`.
- [ ] Thêm dòng ghi chú suffix khác nhau (mục "Cạm bẫy" ở trên).
- [ ] Xoá các câu "Thiếu duy nhất: ảnh Portal" ở đầu `M4.md`, `M6.md` và dòng tương ứng ở `M3.md`.
- [ ] Xoá file này, hoặc rút gọn còn phần M5 nếu quyết định giữ.

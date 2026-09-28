# Cost report — 2026-09-28 (M7)

Số lấy từ **Cost analysis** trên Portal, **Actual cost**, tháng 09/2026. Ảnh chụp 06:53Z (subscription) và
07:37Z (`rg-vsf-dev`) ngày 28/09; dữ liệu Azure trễ 8–24 giờ, nên phần 28/09 chưa có đủ. Credit Free
Trial $200 trừ vào nên hoá đơn là 0, nhưng chi phí thực tế thì **không phải 0**. Chi tiết và các phép
tính: `evidence/M7.md` mục 7 · `notes/d20.md`.

## Tier đang dùng và lý do

- **App Service Plan P0v3 Linux** (1 vCPU / 4 GB, Central India, $0,082/giờ): tier rẻ nhất có **slot**
  (M2) và **autoscale** (M7). B1 không có hai thứ đó; S1 đắt hơn ($0,088/giờ) mà RAM chỉ 1,75 GB.
  Số đo D19: CPU bình thường ~10,5%, memory đỉnh 65% → giữ, không scale up (`evidence/M7.md` mục 4).
- **MySQL Flexible Burstable B1ms** (Southeast Asia): tải thấp, dùng credit CPU của Burstable.
- **ACR Basic** · **Key Vault Standard** · **Log Analytics PerGB2018** (từ D20, cap 0,2 GB/ngày).

## Autoscale

Min 1 · max **2** · scale out khi CPU > 70% trong 5 phút · scale in khi < 30% trong 10 phút. Test thật
(27/09): 1→2 sau 6m35s tải, 2→1 sau 10m43s dừng tải. Instance thứ 2 sống ~12 phút ≈ **$0,016**
(`evidence/M7.md` mục 2).

## 3 biện pháp đã áp dụng (có bằng chứng)

| Biện pháp | Bằng chứng | Tiết kiệm ước tính (giá niêm yết × giờ) |
|---|---|---|
| 1. **Tắt môi trường theo ca** (`make down` cuối buổi) — **chỉ đúng tới 24/09** | Activity Log: 17/09 07:50Z → 24/09 03:08Z (163 giờ), plan chỉ tồn tại **42 giờ (26%)** qua 10 cửa sổ (`evidence/raw/d20-plan-windows-activity-log.tsv`); Daily costs ~$0 ở các ngày tắt | 121 giờ × $0,089 (P0v3 + ACR) ≈ **$10,8** |
| 2. **MySQL tối giản**: B1ms Burstable thay vì General Purpose; 20 GB, không auto-grow, backup 1 ngày, không geo backup, không HA | `infra/app/db.tf:29-43` + `evidence/raw/d20-mysql-cost-settings.json` (`az mysql flexible-server show`) | General Purpose nhỏ nhất (2 vCore × $0,116) so với B1ms: **~$0,21/giờ ≈ $150/tháng** nếu chạy 24/7 |
| 3. **Autoscale min 1, max 2** thay vì chạy cố định 2 instance | `infra/app/autoscale.tf`, Run history + Activity Log `Scaleup`/`Scaledown` (D19) | $0,082/giờ cho instance thứ 2 ≈ **$60/tháng** nếu chạy 24/7; test thật chỉ tốn $0,016 |

**Nói thật về biện pháp 1:** từ **24/09 03:08Z** môi trường **bật liên tục** theo quyết định của người
dùng (để làm D16–D20 liền mạch, không dựng lại mỗi sáng). Tính tới 05:25Z 28/09 là 98 giờ ≈ **$8,7**
đáng lẽ đã tránh được. Hai cửa sổ trước đó cũng đã qua đêm (22→23/09 18 giờ; 23→24/09 7 giờ).

## Chi phí thật

| Phạm vi (tháng 09/2026) | Actual cost | Ghi chú |
|---|---|---|
| **Bài thực tập (`rg-vsf-dev` + D2/D3 + bootstrap)** | **≈ $12,5** | `rg-vsf-dev` $11,97 (06:53Z) → **$12,15** (07:37Z) · `rg-d2-manual` $0,27 · `rg-d3-cli` $0,23 · `rg-vsf-bootstrap` < $0,01 |
| `rg-vsf-dev` theo dịch vụ (07:37Z) | App Service **$11,27** · Container Registry **$0,88** · Key Vault < $0,01 · MySQL **$0,00** | App Service ≈ 137 giờ × $0,082: khớp số giờ plan tồn tại |
| Cả subscription (06:53Z) | $19,17 | Gồm **$6,69** của một PoC khác ngoài phạm vi repo này (RG riêng + 1 web app chạy chung plan) — không tính vào báo cáo |

Ảnh: `evidence/d20/screenshots/m7-cost-daily-by-rg-subscription-20260928-0653.png`,
`m7-cost-rg-vsf-dev-by-service-20260928-0737.png`. Credit còn lại: $181,86 (03:21Z) → $180,63 (~07:30Z).

**MySQL $0,00:** theo giá niêm yết, ~140 giờ B1ms đáng lẽ ~$3,6. Khớp với ưu đãi 12 tháng của tài khoản
Free (750 giờ B1ms/tháng). **Suy luận, chưa đối chiếu** trang Free services — hết ưu đãi thì cộng
~$0,026/giờ.

**Nếu chạy 24/7 cùng cấu hình:** ≈ **$65/tháng** (P0v3 $60 + ACR $5) khi MySQL còn miễn phí; **≈ $87/tháng**
theo giá niêm yết đủ MySQL (B1ms + 20 GB storage), chưa kể Log Analytics (5 GB/tháng đầu miễn phí).

## Chưa tối ưu / lần sau

- **Biện pháp tiết kiệm nhiều nhất là tắt theo ca**: P0v3 là ~93% chi phí (`$11,27 / $12,15`), mà plan
  tính tiền theo giờ tồn tại (kể cả khi app Stop). Đã bỏ nó từ 24/09 → nên bật lại `make down` sau D20
  khi không cần môi trường chạy liên tục.
- Chạy cho người dùng thật 24/7: giữ P0v3 + autoscale; cân nhắc reserved instance / savings plan cho plan
  thường trực; MySQL bật HA + backup dài hơn (đổi tiền lấy độ bền); App Insights sampling < 100%.
- Budget $50/tháng đang có (D1), alert 50/80/100% — chưa gắn action group.
- Chưa tách được chi phí mạng liên vùng (app Central India ↔ MySQL Southeast Asia) — số rất nhỏ ở quy mô này.

# Cost report — 2026-09-28 (M7), cập nhật số 2026-10-01

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

**Cập nhật 01/10 (trước D25)** — Cost Management Query API, Actual cost 01/09→01/10 (01/10 mới có một phần), số thô
`evidence/raw/d25-cost-api-20261001.tsv`: `rg-vsf-dev` **$19,38** (App Service $17,83 · ACR $1,44 · Azure Monitor $0,10
· Key Vault $0,01 · MySQL $0,00) · bài thực tập tổng **≈ $19,9**. Từ 25/09 mỗi ngày **$2,13–2,18** = đúng 24 giờ P0v3
($1,97) + ACR Basic ($0,17): môi trường bật liên tục, Log Analytics/App Insights gần như không tốn (< 5 GB/tháng miễn phí).
**Số chốt cho "đáng lẽ tránh được" của biện pháp 1: ≈ $16** (24/09 03:08Z → 01/10 17Z = 182 giờ × $0,089; thay số $8,7 ở trên vốn chỉ tính tới 28/09). PoC ngoài repo
(`rg-obs-poc` + 1 web app chung plan) ≈ $20,5 — không tính. Ảnh Cost analysis cuối cùng: chụp sau demo (guide D25 mục 4).

**MySQL $0,00:** theo giá niêm yết, ~140 giờ B1ms đáng lẽ ~$3,6. Khớp với ưu đãi 12 tháng của tài khoản
Free (750 giờ B1ms/tháng). **Suy luận, chưa đối chiếu** trang Free services — hết ưu đãi thì cộng
~$0,026/giờ.

**Nếu chạy 24/7 cùng cấu hình:** ≈ **$65/tháng** (P0v3 $60 + ACR $5) khi MySQL còn miễn phí; **≈ $87/tháng**
theo giá niêm yết đủ MySQL (B1ms + 20 GB storage), chưa kể Log Analytics (5 GB/tháng đầu miễn phí).

## Chưa tối ưu / lần sau

- **Biện pháp tiết kiệm nhiều nhất là tắt theo ca**: P0v3 là ~93% chi phí (`$11,27 / $12,15`), mà plan
  tính tiền theo giờ tồn tại (kể cả khi app Stop). Đã bỏ nó từ 24/09 và **không bật lại được trước D25**: một PoC
  khác chạy chung plan, `make down` sẽ gãy (`known-issues.md` #23) — người dùng chốt giữ môi trường tới demo. Sau demo: gỡ PoC
  rồi `make down`.
- Chạy cho người dùng thật 24/7: giữ P0v3 + autoscale; cân nhắc reserved instance / savings plan cho plan
  thường trực; MySQL bật HA + backup dài hơn (đổi tiền lấy độ bền); App Insights sampling < 100%.
- Budget $50/tháng đang có (D1), alert 50/80/100% — chưa gắn action group.
- Chưa tách được chi phí mạng liên vùng (app Central India ↔ MySQL Southeast Asia) — số rất nhỏ ở quy mô này.

## Advanced — AKS (ngoài `topic.md`, thêm 2026-10-12)

Phần làm thêm, **không** thuộc 1 trang của M7 ở trên. Số ở đây là **giá niêm yết × số giờ**, chưa phải Actual cost:
cluster dựng 12/10 04:23Z, Cost analysis trễ 8–24 giờ. Chi tiết đo đạc: `evidence/advanced/aks-m7.md`.

| | App Service (bài chính) | AKS (advanced) |
|---|---|---|
| Region | Central India | East Asia (Free Trial: hết quota ở Central India, D-series bị chặn ở Southeast Asia) |
| Đơn vị tính tiền | Plan P0v3 1 vCPU / 4 GB — $0,082/giờ | Node D2as_v5 2 vCPU / 8 GB — $0,119/giờ (cùng size ở Central India: $0,056) |
| Phí nền tảng | gồm trong Plan | control plane tier Free $0 · Load Balancer ~$0,025/giờ · 2 public IP $0,010/giờ · đĩa OS $0,008/giờ |
| Tổng khi rỗi | **≈ $0,09/giờ ≈ $2,15/ngày** (đo thật, kèm ACR) | **≈ $0,16/giờ ≈ $3,9/ngày** (niêm yết) |
| Ở mức tối đa 2 | ≈ $0,17/giờ (2 instance) | ≈ $0,29/giờ (2 node); 2 **pod** trên 1 node thì không tốn thêm |
| Dùng chung, không tính lại | — | ACR, Key Vault, MySQL của bài chính |
| Log | workspace `log-vsf-*`, cap 0,2 GB/ngày | workspace riêng `log-vsf-aks-*`, cap 0,2 GB/ngày; chỉ thu namespace của app |

Đọc bảng này thế nào: với **một app nhỏ**, AKS đắt hơn App Service khoảng 1,8 lần ($0,16 so với $0,09 mỗi giờ) — nhưng hai
số **không cùng cơ sở**: $0,09 là Actual cost đo thật, gồm ACR; $0,16 là giá niêm yết, không gồm ACR (dùng chung). Khoảng
**90% chênh lệch là do region**, không phải do nền tảng: riêng node đã chênh $0,063/giờ giữa East Asia ($0,119) và Central
India ($0,056), trên tổng chênh ~$0,07. Cùng region thì hai bên gần ngang nhau. Điều thuộc về nền tảng là ~78% CPU request
của node dành cho add-on chứ không phải cho app (`evidence/advanced/aks-m7.md` mục 3) — AKS chỉ rẻ dần khi nhiều app chia
nhau cùng node và cùng add-on, không phải trường hợp của bài này.

Biện pháp đã áp dụng: control plane tier Free · cluster autoscaler min 1 / max 2 · `make aks-down` cuối buổi · Container
Insights chỉ thu một namespace, không bật managed Prometheus/Grafana (dịch vụ tính tiền riêng).

Hai chỗ **tốn hơn** so với dự tính ban đầu, đều đo được 12/10: (1) mỗi lần CD-AKS chạy kéo node thứ hai lên ~15–25 phút
(≈ $0,03–0,05 mỗi lần deploy, `known-issues.md` A13); (2) `be` và `fe` chạy cố định 2 bản thay vì co giãn 1–2 — đổi lấy
việc gỡ node không lấy mất bản cuối. Hai bản vẫn vừa một node nên (2) không thêm tiền máy.

Chưa có: Actual cost từ Cost analysis cho `rg-vsf-aks` + `rg-vsf-aks-nodes` — đọc được từ 13/10.

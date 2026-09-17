# D2 — Deploy tay bằng Portal (2026-09-16, 09:19 → 12:05)

Nhật ký đầy đủ: `notes/d2.md` · Ảnh: `d02/screenshots/` (28 ảnh)

## Đã dựng bằng tay
`rg-d2-manual` (Southeast Asia): MySQL `mysql-d2-3082` (B1ms, 20 GiB, 8.4) · App Service Plan `ASP-rgd2manual-8c56` · Web App `app-d2-3082` (container mẫu) · slot `staging`

## Bằng chứng theo yêu cầu của đề (bản làm tay)

| Yêu cầu | Bằng chứng | File |
|---|---|---|
| Tier Basic **không có** deployment slot | Portal: *"Upgrade to a standard or premium plan to add slots"* | `screenshots/slots-blocked-on-basic-20260916-0933.png` |
| Không hạ được tier khi đang có slot | *"The site(s) 'app-d2-3082' exceed maximum number of slots allowed for the hosting plan"* | `screenshots/scaleup-b1-failed-slots-20260916-1157.png` |
| Bảng giá thật (Portal = Retail API) | B1 0.018 · P0V3 0.092 · S1 0.095 (Legacy) | `screenshots/scaleup-p0v3-selected-20260916-0935.png` |
| **M6 bản làm tay**: IP whitelist | 200 từ IP đã allow · **403 từ LTE** | `screenshots/403-from-lte-20260916-1052.png` |
| Outbound IP: current ≠ possible | **7** current vs **20** possible | `screenshots/outbound-ips-20260916-0942.png` |
| MySQL data plane | kết nối bằng mysql-client + TLS, CREATE/INSERT/SELECT | `screenshots/mysql-connected-select-20260916-1037.png` |
| Swap có gián đoạn | poll mỗi giây: **1 dòng `000`** lúc 11:47:32 (timeout 3s) | `screenshots/swap-poll-000-20260916-1147.png` |
| Dọn sạch | RG xoá lúc 12:05, Portal trả 404 | `screenshots/rg-deleted-404-20260916-1205.png` |

## Ba con số rút ra
- **7 vs 20** outbound IP → firewall MySQL phải sinh từ danh sách *possible* (M3)
- **P0V3 $0.092/h** rẻ hơn **S1 $0.095/h** mà RAM gấp đôi → lập luận cho cost report (M7)
- Swap "trần" mất **~4 giây** → cần warm-up + health check + tắt êm (M2)

## Chi phí
Môi trường sống 2h45 → ước tính ≈ **$0.30**. Số thật: xem `d05/README.md`.

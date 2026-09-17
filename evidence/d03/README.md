# D3 — Làm lại bằng Azure CLI (2026-09-16, 13:45 → 16:07)

Nhật ký đầy đủ: `notes/d3-cli.md` · Ảnh: `d03/screenshots/`

## Đã dựng lại bằng CLI
`rg-d3-cli`: MySQL `mysql-d3-3082` (**5'37"**) · Plan `asp-d3-cli` P0V3 (**8.6 giây**) · Web App `app-d3-3082` (**42 giây**) · 20 firewall rule tạo bằng vòng lặp shell · access restriction · slot + swap (**1'05"**) · scale 1→2→1

## Phát hiện chính: script CLI tạo được nhưng không *giữ* được hạ tầng

| Lệnh chạy lần 2 | Kết quả | Loại |
|---|---|---|
| `az group create` | im lặng thành công | idempotent thật |
| `az mysql flexible-server firewall-rule create` | vẫn 21 rule | idempotent |
| **`az webapp create`** | cảnh báo nhẹ, **`httpsOnly` bị reset true → false** | ⚠️ exit code 0 nhưng hạ cấu hình bảo mật |

Kiểm chứng 16:05: production `httpsOnly=False`, slot staging `httpsOnly=True` (slot clone lúc production còn true ⇒ loại trừ nguyên nhân do swap).

→ Đây là câu trả lời cho câu hỏi GATE D10 *"vì sao cần Terraform thay vì script"*.

## Portal đã giấu gì (đầu vào cho D8)

| Thuộc tính | Portal (D2) | CLI (D3) |
|---|---|---|
| `httpsOnly` | true | **false** |
| Hostname | có hậu tố ngẫu nhiên | không có |
| `alwaysOn` | false | true |
| `linuxFxVersion` | `sitecontainers` | `DOCKER\|...` |
| `scmIpSecurityRestrictionsUseMain` | **true** | **false** → SCM thành deny-all, chặn cả chính mình (403) |
| Tier plan | tự chọn B1 | phải ghi rõ `--sku` |
| Database MySQL | phải tự `CREATE DATABASE` | `--database-name` tạo sẵn |

## Sự cố bảo mật
`az mysql flexible-server create` **in mật khẩu admin ra stdout**. Quyết định: không xoay vòng vì server bị xoá trong ngày. Phòng ngừa: `-o none`, và lọc output trước khi copy. Chi tiết trong `notes/d3-cli.md`.

## Chi phí
2h20 → ước tính ≈ **$0.28**.

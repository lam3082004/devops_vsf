# Báo cáo kiểm thử

Tổng hợp mọi kịch bản kiểm thử của dự án: chạy gì, kết quả, bằng chứng ở đâu. Chi tiết và log thô nằm trong
`evidence/` (bảng M1–M11: [`evidence/README.md`](evidence/README.md)). Cập nhật 2026-10-01 (D24).

## 1. Kiểm thử tự động (CI, mọi PR)

| Kiểm | Công cụ | Kết quả gần nhất | Ghi chú |
|---|---|---|---|
| Unit + integration `be` | xUnit, MySQL 8.4 service container trong CI | 154 test (12 test cần MySQL chỉ chạy ở CI) | `make test` local: 142 pass, 12 skip vì không có MySQL |
| Unit `fe` | `node:test` | 14/14 pass | `make fe-test`. `src/lib/api.ts` và route handler cũ chưa có test (`known-issues.md` #16) |
| Lint / format | `dotnet format`, `eslint` | sạch | |
| Build + chặn prerender tĩnh | `next build` + đọc `prerender-manifest.json` | xanh | chặn lại bug D16 (`known-issues.md` #18) |
| Terraform | `fmt -check`, `validate`, `plan` bằng `id-gh-plan` | xanh | |
| Secret | gitleaks 8.30.1 (CI + pre-commit) | 0 leak | |
| Image | Trivy 0.74.0, cổng CRITICAL/HIGH, không `--ignore-unfixed` | xanh, có 1 ngoại lệ có hạn tới 15/10 | `known-issues.md` #31 |
| SAST | Semgrep 1.177.0 (C#, TS/Next.js, Dockerfile, Actions), cổng ERROR | 0 ERROR (3 SQLi dương tính giả đánh dấu `nosemgrep` kèm lý do) | PR DevSecOps 01/10 |
| IaC / Dockerfile misconfig | `trivy config`, cổng HIGH/CRITICAL | 0 (sửa `USER` của `be`; 2 ngoại lệ Azure có lý do trong `.trivyignore`) | PR DevSecOps 01/10 |
| **CI chặn được cái sai (M9)** | 6 PR cố tình sai | 6/6 đỏ đúng job | [`evidence/M9.md`](evidence/M9.md) |

## 2. Kịch bản trên môi trường thật

| # | Kịch bản | Kết quả | Bằng chứng | Ngày |
|---|---|---|---|---|
| 1 | Health/version sau deploy | `be /version` = `fe /api/version` = SHA `main` | [`M10.md`](evidence/M10.md), [`M8.md`](evidence/M8.md) mục Lần cuối | 16/09 → 01/10 |
| 2 | Pull image bằng MI, ACR admin tắt (M1) + gỡ AcrPull → `ACRTokenRetrievalFailure` | đạt | [`M1.md`](evidence/M1.md) | 21–23/09 |
| 3 | Zero-downtime khi swap (M2) | 0 response non-200 trong 4 lần swap; có cụm timeout client chưa quy được nguyên nhân (#21) | [`M2.md`](evidence/M2.md) | 27/09 |
| 4 | Firewall MySQL = outbound IP (M3) | 31 rule = 31 IP | [`M3.md`](evidence/M3.md) | 22/09 |
| 5 | Không secret plaintext, Key Vault reference (M4) | đạt | [`M4.md`](evidence/M4.md) | 22/09 |
| 6 | Gỡ quyền Key Vault → app gãy → trả quyền (M5) | `AccessToKeyVaultDenied`, container exit 1 sau 0,2 s → hồi phục, `plan` No changes | [`M5.md`](evidence/M5.md) | 22–23/09 |
| 7 | IP whitelist 200/403 trên 8 bề mặt (M6) | 8/8 bị chặn đúng 403 từ IP runner (đo lại 01/10) | [`M6.md`](evidence/M6.md), `m6-check` run `36822644120`, `36822651677` | 23/09 → 01/10 |
| 8 | Autoscale 1 → 2 → 1 (M7) | Scaleup 16:20:42Z, Scaledown 16:32:37Z | [`M7.md`](evidence/M7.md) | 27/09 |
| 9 | Terraform destroy → apply từ rỗng (M8) | 36 resource, apply 24 phút, plan No changes | [`M8.md`](evidence/M8.md) | 21/09 |
| 10 | Dựng lại từ clone mới theo README (M8 lần cuối, **không** destroy) | `plan` + `make up` 0 thay đổi cả 2 root; README sửa 3 chỗ | [`M8.md`](evidence/M8.md) mục Lần cuối | 01/10 |
| 11 | CD chỉ từ `main`, swap an toàn, rollback tự động (M10) | 3 tình huống lỗi dừng trước swap, rollback tự động chạy thật | [`M10.md`](evidence/M10.md) | 23–26/09 |
| 12 | Alert 5xx Fired → Resolved, truy vết alert → request (M11) | Fired ~4–5 phút sau lỗi đầu (drill 2 D24: 2′17″), Resolved ~20–26 phút sau lỗi cuối; email không tới 29/09, **tới thật 01/10** (#28, 4 ảnh `evidence/d24/screenshots/`) | [`M11.md`](evidence/M11.md) | 29/09 |
| 13 | Agent giới hạn quyền: 2 phép được phép + 9 phép bị cấm | 9/9 bị chặn đúng loại lỗi | [`agent.md`](evidence/agent.md) | 01/10 |
| 14 | **Drill 1**: mất firewall MySQL → apply | MTTR 10 phút 58 giây, alert mù với lỗi một phần | [`docs/drills/2026-10-01-firewall.md`](docs/drills/2026-10-01-firewall.md) | 01/10 |
| 15 | **Drill 2**: deploy bản lỗi → swap ngược | CI 8/8 xanh + CD success trên bản lỗi (cổng CD không kiểm `/items`); alert 2 phút 17 giây; swap ngược 39 giây; RTO 12 phút 39 giây (7 phút chờ người chạy swap) | [`docs/drills/2026-10-01-bad-deploy.md`](docs/drills/2026-10-01-bad-deploy.md) | 01/10 |
| 16 | Rollback / phục hồi (4 kịch bản) | xem bảng | [`docs/rollback.md`](docs/rollback.md) | 22/09 → 01/10 |
| 17 | DevSecOps: smoke staging, ZAP, SBOM, SAST, IaC, drift | CD `36833482956`: smoke 4/4 → swap, ZAP 0 FAIL, SBOM 38/42 component; CI job `sast + iac` 0 ERROR; `drift.yml` run `36833646432` 0 drift. **Chưa có ca đỏ thật** cho smoke/drift | [`evidence/devsecops.md`](evidence/devsecops.md) | 01/10 |

## 3. Chưa kiểm hoặc kiểm chưa đủ

- **MySQL point-in-time restore**: không làm (tạo thêm server, chi phí và thời gian). Lý do trong `docs/rollback.md`.
- **Destroy → apply** với hạ tầng tuần 3–5: chưa (`known-issues.md` "Chưa xong" #7).
- Đo M2 từ điểm gần region: chưa (#21). Test tải chỉ dùng `scripts/load.sh` (curl song song), không có k6/JMeter.
- `fe`: `api.ts` và route handler cũ chưa có test (#16).
- Cross-review × 2: không làm ("Chưa xong" #6).

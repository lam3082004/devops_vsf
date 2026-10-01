# DevSecOps — các lớp bảo mật của pipeline (PR #75, 2026-10-01)

Người dùng yêu cầu giữa drill 2 D24: "bổ sung các job CI/CD sao cho project là một project DevSecOps chuyên nghiệp,
chỉ những job thực sự cần thiết". Lựa chọn giữ/bỏ: plan, Decisions 01/10. Tổng quan: README mục "Các lớp bảo mật
trong pipeline". Giới hạn: `known-issues.md` #32.

## Bằng chứng chạy thật

| Lớp | Run | Kết quả |
|---|---|---|
| SAST Semgrep 1.177.0 (CI, cổng ERROR) | CI của PR #75, job `sast + iac (semgrep, trivy config)` | `Ran 116 rules on 146 files`: 0 ERROR · 5 WARNING (`github-actions-mutable-action-tag`, chỉ theo dõi) |
| IaC / Dockerfile misconfig (CI, cổng HIGH/CRITICAL) | cùng job | đạt. Trước khi sửa: `DS-0002` (`be` không khai `USER`), `AZU-0012` (storage state), `AZU-0013` (Key Vault) → sửa `USER $APP_UID`, 2 ngoại lệ có lý do trong `.trivyignore` |
| Required check | ruleset `protect-main` | 9 check (thêm `sast + iac`), 0 bypass, sau merge #75 |
| SBOM CycloneDX (CD) | CD `36833482956` (merge #75, `85d9ef0`), artifact `sbom-85d9ef0…` | `be` 38 component · `fe` 42 component |
| Smoke nghiệp vụ staging (CD, chặn swap) | CD `36833482956` | 08:04:15–08:04:19Z: `be GET /items` 200 · `/items?limit=1` 200 · `/stats` 200 · `fe GET /` 200 → swap |
| DAST ZAP 2.16.1 baseline thụ động (CD, chỉ cảnh báo) | CD `36833482956`, artifact `zap-baseline-85d9ef0…` | `be`: FAIL-NEW 0 · WARN-NEW 6 · PASS 61 — `fe`: FAIL-NEW 0 · WARN-NEW 11 · PASS 56. Cảnh báo chính: thiếu HSTS (×4), thiếu `X-Content-Type-Options`, cache-control |
| Dọn luật IP tạm sau CD có thêm smoke/ZAP | `az webapp config access-restriction show` 4 bề mặt, 01/10 sau CD | 0 luật `cd-*` còn lại |
| Drift detection (`drift.yml`, `plan -refresh-only`) | run `36833646432` (dispatch, `main`) | success: plan đầy đủ (bước plan 82 giây, không đi nhánh "môi trường tắt"), 0 drift thật. Local trước đó: 4 Web App/slot "đổi" do tag image CD đặt → bộ lọc loại đúng |
| Danh tính drift | `terraform apply` bootstrap từ checkout chính | `2 added` (credential `environment:drift-check` cho `id-gh-plan`) → `plan` No changes; state sao lưu `~/vsf-state-backup/` |
| Dependabot | `.github/dependabot.yml` | NuGet, npm, Actions hằng tuần. **Chưa có PR nào** để kiểm đường CI của Dependabot (#32 mục 3) |

## Chưa chứng minh

- Smoke **chặn thật** một bản lỗi: chỉ chứng minh bằng lập luận (drill 2 cho `/items` 503, smoke đòi 200 + `items` là
  mảng) và chạy logic smoke trên production bản tốt. Muốn có bằng chứng chạy thật thì lặp lại drill 2 (thêm 1 PR lỗi
  + 1 revert = 2 lần CD), chưa làm.
- Drift workflow **đỏ** khi có drift thật: chưa gây drift lại sau drill 1. Bộ lọc giữ nguyên mọi thay đổi ngoài 2
  thuộc tính image, nên rule firewall bị xoá (drill 1) sẽ ra `actions: ["delete"]`.

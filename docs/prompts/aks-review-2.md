# Prompt cho sub-agent Sonnet — review AKS lần 2 (sau P3–P5)

Bạn là reviewer độc lập, **chỉ đọc**. Không sửa file, không `git commit/push`, không `terraform apply|destroy`, không
`az ... create|delete|update`, không `kubectl apply|delete|scale|set|rollout undo|exec|run`, không `gh pr merge`, không
`gh workflow run`. Được chạy lệnh đọc: `ls`, `grep`, `git`, `gh pr view|checks`, `gh run view|list`, `gh api` GET,
`terraform -chdir=infra/aks validate|output|state list`, `kubectl get|describe|logs|top`, `kubectl kustomize`,
`az ... show|list`, `az graph query`, `shellcheck`, `make aks-verify`.
Repo `/home/tts/desktop/devops_vsf`. Không chạy `terraform plan` (có tiến trình khác dùng state).

## Bối cảnh
Phần *advanced* (ngoài `topic.md`): cùng app OpsBoard chạy thêm trên AKS, **chỉ thêm, không đụng thứ đã có**. Review lần 1
(`docs/prompts/aks-review-1.md`) đã soi code P0–P2. Lần này soi **bằng chứng và phép đo** của P3 (chứng minh ngược, whitelist),
P4 (CI, CD, zero-downtime) và P5 (autoscale, chi phí) — tức câu hỏi là *khẳng định trong tài liệu có đúng với log thô và với
cluster thật không*, không phải code có đẹp không.

## Đọc trước
`docs/plans/active/aks-advanced.md` (mục Tiến độ, Recovery) → `evidence/advanced/README.md` → từng file `evidence/advanced/aks-*.md`
→ log thô tương ứng trong `evidence/raw/aks-*` → `notes/aks.md` → `known-issues.md` mục "Phần advanced: AKS" (A1…) →
`ai-failure-log.md` #46 trở đi → `cost-report.md` mục "Advanced — AKS" → `docs/aks.md`.

## Việc 1 — Mỗi con số có nguồn không
Với **từng** dòng có thời điểm, thời lượng, mã HTTP, số lượng trong `evidence/advanced/aks-m1.md`, `aks-m4-m5.md`, `aks-m6.md`,
`aks-m7.md`, `aks-m9-m10-m2.md` (nếu có) và `cost-report.md` mục AKS:
1. Tìm đúng dòng log thô chứng minh nó. Liệt kê con số **không tìm thấy nguồn** hoặc **lệch** với log (kể cả lệch vài giây,
   phép trừ thời gian sai, đơn vị sai).
2. Khẳng định so sánh với App Service ("nhanh hơn khoảng 6 lần", "đắt hơn khoảng 1,8 lần", "78%"): tính lại từ số gốc
   (`evidence/M7.md`, `cost-report.md` phần trên, log) — đúng không, và so sánh có công bằng không (khác region, khác đơn vị)?
3. Giá niêm yết: có chỗ nào viết như thể là **Actual cost** không? Dòng nào tự nhận "không tra được" — có ghi rõ là ước tính?
4. Run GitHub được trích (số run, kết quả, SHA): `gh run view <id>` có khớp không.

## Việc 2 — Phép đo có chứng minh đúng điều nó nói không
1. **M5 trên AKS**: log có đủ để nói "app gãy" không, hay chỉ là "pod mới không lên"? Trình tự gỡ quyền → lỗi → trả quyền →
   hồi phục → `plan` No changes có đủ cả 5 mốc trong log không?
2. **M1 ngược**: `401 Unauthorized` trong log có đúng là do mất `AcrPull` (so thời điểm apply) hay có thể do nguyên nhân khác?
   Alert `Fired` — kiểm lại bằng `az graph query` trên `alertsmanagementresources`; nó đã `Resolved` chưa và tài liệu nói gì?
3. **M6**: bề mặt nào đã đo từ IP ngoài, bề mặt nào chỉ đo từ trong whitelist? Tài liệu có nói quá không? "timeout" có thể bị
   nhầm với "cluster đang tắt" — phép đo có ca đối chứng (200 từ IP cho phép, cùng lúc) không?
4. **M2/M10 trên AKS** (nếu đã có): số response non-200 và số timeout trong log `m2-poll`; cột `sha` có đổi A→B cho cả `be` lẫn
   `fe`; `be` được đo qua `kubectl proxy` — độ trễ/timeout của đường đó có bị tính nhầm thành downtime của app không? Run
   `cd-aks.yml` thật có dùng danh tính `id-gh-aks-deploy` (không phải danh tính admin) và có chạy tới bước kiểm không?
   Nhánh rollback đã được chạy thật chưa hay mới chỉ thử bằng danh tính người vận hành?
5. **M7**: HPA 1→2→1 và node 1→2→1 — mốc thời gian lấy từ đâu, khoảng lấy mẫu 15–20 giây có làm sai số lớn hơn con số được
   công bố không ("62 giây", "45 giây")? Phép thử node dùng pod giữ chỗ chứ không phải tải thật — tài liệu có nói rõ không?
6. Trạng thái thật **bây giờ** của cluster có khớp phần "đã trả lại": `kubectl -n opsboard get deploy,hpa,networkpolicy`,
   `kubectl get ns` (không còn namespace thử), số node, role assignment của kubelet identity và của `id-vsf-aks-be/fe`
   (`az role assignment list --assignee <principalId> --all`), `scripts/aks-verify.sh`.

## Việc 3 — Ranh giới và sự thật chung
1. `git diff origin/main --stat` trên nhánh đang làm và PR đang mở (`gh pr list`): file cũ nào bị sửa ngoài kiểu "nối thêm cuối"?
   PR #95 (vá `sharp`) có đúng chỉ đổi `app/fe/package-lock.json` và chỉ các gói `sharp`/`@img/*` không?
2. Môi trường cũ: `evidence/raw/aks-guard-*.log` có đủ cho từng pha tài liệu nêu không; lần cuối là `0 FAIL`?
3. IP đầy đủ / secret / email trong mọi file mới (`grep -rnE '[0-9]{1,3}(\.[0-9]{1,3}){3}' evidence/advanced evidence/raw/aks-* docs/aks.md notes/aks.md`
   — chỉ chấp nhận dải tài liệu, dải nội bộ, IP đã che `x.x`); `gitleaks detect --no-git --source evidence`.
4. `evidence/advanced/README.md`: cột trạng thái có nói thật không — phần nào ghi "đạt" mà thực ra chưa đo đủ, phần nào chưa làm
   mà không ghi? Mỗi file có banner "PHẦN ADVANCED — ngoài phạm vi topic.md" không?
5. `known-issues.md` A1…: có vấn đề nào bạn thấy trong lúc review mà **chưa** được ghi không?

## Báo cáo (tiếng Việt, ≤ 70 dòng)
Mỗi phát hiện: **mức** (P0 làm hỏng môi trường cũ / lộ bí mật · P1 sai sự thật hoặc phép đo không chứng minh điều được nói ·
P2 nên sửa · P3 nhỏ) · `file:dòng` · bằng chứng (lệnh + output ngắn) · cách sửa đề xuất. Không khen chung chung.
Kết thúc bằng: danh sách khẳng định **đã kiểm chứng đúng** (kèm nguồn), danh sách **không kiểm được và vì sao**, và phán quyết
GO/NO-GO cho việc merge PR bằng chứng.

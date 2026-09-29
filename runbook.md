# Runbook — Alert "5xx rate > 5% (be/fe production)"

Alert nghiêm trọng nhất của hệ thống (Sev 1, `topic.md` deliverable 6). Rule:
`alert-vsf-5xx-rate` (`infra/app/alerts.tf`) — tỷ lệ 5xx của `be` **hoặc** `fe` production > 5% trong
10 phút, tối thiểu 20 request, đánh giá 5 phút/lần, tự đóng khi hết điều kiện.

> Hai alert còn lại (`alert-vsf-cpu-high` Sev 2, `alert-vsf-mysql-connections` Sev 2) dùng chung các bước
> **Xác nhận** 1, 3, 5 và bảng **Xử lý** bên dưới (dòng "Quá tải", "DB").
>
> Ký hiệu: `<suffix>` = hậu tố môi trường (`terraform -chdir=infra/app output -raw name_suffix`).
> Mọi lệnh `curl` chạy từ máy trong whitelist (M6) và ép `-4`. Không có quyền Azure → nhảy thẳng tới **Escalate**.

> **Điều kiện để có email:** địa chỉ trong `ag-vsf-oncall` phải được **xác minh OTP** (Azure gửi mã khi lưu action group,
> hạn 30 phút; hết hạn → Portal → Monitor → Alerts → Action groups → `ag-vsf-oncall` → Resend). Chưa xác minh thì alert
> vẫn Fired trên Portal/Workbook nhưng **không có email** (`known-issues.md` #28). Trên subscription Free Trial hiện tại,
> email **không tới kể cả khi đã xác minh** (drill 2, 29/09) → người trực theo dõi Workbook ô "Alert 7 ngày qua" / Portal Alerts.

## Triệu chứng

- Email `Fired:Sev1 … 5xx rate > 5% (be/fe production)` gửi tới action group `ag-vsf-oncall`.
- Người dùng thấy banner "lỗi backend" trên `fe`, hoặc API trả 500/503.

## Xác nhận (≤ 5 phút)

1. **App nào, lỗi gì, từ lúc nào.** Mở Workbook **OpsBoard — M11** (Portal → Monitor → Workbooks, hoặc link
   trong `evidence/M11.md`), khoảng thời gian 1 giờ: hàng 1 (failure rate, response time) + ô "Lỗi mới nhất".
   Hoặc chạy KQL trên workspace `log-vsf-<suffix>` (Portal → Log Analytics workspace → Logs):

   ```kusto
   // Q2 — % 5xx theo 5 phút, theo app (docs/logging.md)
   AppServiceHTTPLogs
   | where TimeGenerated > ago(1h)
   | where _ResourceId has "/sites/" and _ResourceId !has "/slots/"
   | extend app = tostring(split(_ResourceId, "/")[8])
   | summarize total = count(), errors = countif(ScStatus >= 500) by bin(TimeGenerated, 5m), app, CsUriStem
   | where errors > 0
   | order by TimeGenerated desc
   ```

   → biết **app** (`app-vsf-…` = be, `fe-vsf-…` = fe), **path** và **giờ bắt đầu**.

2. **Lỗi cụ thể + trace_id** (Q5 — log JSON của app). Dòng `level = error` cho biết *lỗi gì* (`event`,
   `error`, `detail`); dòng `event = request` có `status >= 500` mang **`trace_id`** của đúng request đó:

   ```kusto
   AppServiceConsoleLogs
   | where TimeGenerated > ago(1h)
   | extend log = parse_json(ResultDescription)
   | where tostring(log.level) == "error" or toint(log.status) >= 500
   | project TimeGenerated, level = tostring(log.level), event = tostring(log.event),
             path = tostring(log.path), status = toint(log.status), error = tostring(log.error),
             detail = tostring(log.detail), trace_id = tostring(log.trace_id)
   | order by TimeGenerated desc
   ```

3. **Truy vết một request lỗi** (alert → log → trace): lấy một `trace_id` ở bước 2 →

   ```kusto
   union AppRequests, AppDependencies, AppExceptions
   | where OperationId == "<trace_id>"
   | project TimeGenerated, Type, AppRoleName, Name, ResultCode, DurationMs, ProblemId
   | order by TimeGenerated asc
   ```

   Hoặc Portal → Application Insights `appi-vsf-<suffix>` → **Transaction search** → dán `trace_id` → *End-to-end
   transaction*: thấy `fe` → `be` → MySQL và chặng nào lỗi. (Không chụp trang Overview — có connection string.)

4. **`/health` production:** `curl -4 -s -w ' %{http_code}\n' https://app-vsf-<suffix>.azurewebsites.net/health`
   — `200 {"status":"ok","db":"ok"}` = app + DB sống; `503` = không ping được DB hoặc schema chưa sẵn sàng.

5. **Có deploy gần đây không?** `gh run list --workflow cd.yml --limit 3` (giờ merge/swap) và
   `curl -4 -s https://app-vsf-<suffix>.azurewebsites.net/version` (SHA đang chạy). Lỗi bắt đầu **ngay sau** một
   lần swap → nghi bản mới.

6. **Key Vault reference / MySQL:**
   `az rest --method get --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/rg-vsf-dev/providers/Microsoft.Web/sites/app-vsf-<suffix>/config/configreferences/appsettings?api-version=2022-03-01" --query "value[].{k:name,s:properties.status}" -o table`
   (mọi dòng `Resolved`) · `az mysql flexible-server show -g rg-vsf-dev -n mysql-vsf-<suffix>-sea --query state -o tsv` (`Ready`).

## Xử lý theo nguyên nhân

| Nguyên nhân | Dấu hiệu (từ bước xác nhận) | Hành động |
|---|---|---|
| Bản deploy mới lỗi | Lỗi bắt đầu ngay sau swap (bước 5), SHA mới | **Rollback** (mục dưới) rồi mở issue/PR sửa |
| DB không kết nối | `/health` 503, log `db_error`/`schema_*`, MySQL không `Ready` | Kiểm MySQL state + CPU/connections trên Workbook hàng 3; firewall MySQL so với outbound IP của app (`terraform plan` phải ra No changes); MySQL `Stopped` → `az mysql flexible-server start` (⚠️ hỏi chủ repo — tốn tiền) |
| Mất secret | KV reference không `Resolved` (bước 6), container restart liên tục | Kiểm role `Key Vault Secrets User` của `id-vsf-app-<suffix>` trên vault → `terraform plan`/`apply` trả lại (M5) |
| Quá tải | CPU plan cao / HTTP queue dài (Workbook hàng 2), alert CPU cùng bắn | Xác nhận autoscale đã lên **2** (tối đa, luật project — không nâng); tìm nguồn tải (`/load`? script quên dừng?) và dừng |
| Endpoint lỗi cố ý (`/boom`) | Chỉ path `/boom` (bước 1), `event = boom` (bước 2) | Xác nhận là test/drill (ai chạy `scripts/boom.sh`?), ghi chú vào sự cố; alert tự đóng sau ~10–15 phút khi hết lỗi |

## Rollback (swap ngược)

Bản trước vẫn nằm ở slot **staging** ngay sau một lần CD (swap đổi chỗ, không xoá) — **nếu chưa có CD mới đè lên**.
Thứ tự như bước rollback của `.github/workflows/cd.yml`: **`fe` trước, `be` sau**.

```bash
az webapp deployment slot swap -g rg-vsf-dev -n fe-vsf-<suffix>  --slot staging --target-slot production
az webapp deployment slot swap -g rg-vsf-dev -n app-vsf-<suffix> --slot staging --target-slot production
```

Kiểm sau rollback: `/version` (be) và `/api/version` (fe) = SHA cũ; Workbook failure rate về 0 sau 5–10 phút;
alert chuyển **Resolved** (email). Swap là thao tác trên production — người trực có quyền `Website Contributor`
mới chạy được; nếu không → Escalate.

**Không được:** sửa tay cấu hình trên Portal rồi quên đưa vào Terraform (lần `terraform plan` sau sẽ kéo ngược —
M8). Sửa tạm trên Portal thì ghi lại ngay và mở PR cùng ngày.

## Escalate

- **Khi nào:** chưa xác định nguyên nhân sau **30 phút** · rollback không làm failure rate giảm · nghi lộ secret
  (connection string, mật khẩu DB) · swap ngược thất bại (production ở trạng thái không xác định).
- **Liên hệ:** mentor (kênh liên lạc của kỳ thực tập) — chủ repo `lam3082004`.
- **Gửi kèm:** giờ bắt đầu (UTC), link alert (trong email), truy vấn đã chạy + kết quả, `trace_id` mẫu, hành động
  đã làm và kết quả.

## Sau sự cố

- Timeline (giờ UTC: bắt đầu, alert Fired, xác nhận, xử lý, Resolved), nguyên nhân, action item →
  `known-issues.md` (một dòng mới).
- Bước nào của runbook làm không được / chậm → sửa file này cùng PR.

## Mốc thời gian đo thật (drill 29/09)

| Mốc | Thời gian |
|---|---|
| Lỗi bắt đầu → alert **Fired** | 4 phút 40 giây (06:42:59 → 06:47:39Z) |
| Lỗi cuối cùng → alert **Resolved** | ~23 phút (06:51:00 → 07:13:44Z) — alert đóng sau vài lượt đánh giá (5 phút/lần) không đạt điều kiện, **không** phải ngay khi hết lỗi |
| Log request về workspace | 2–5 phút |

→ Đã rollback/sửa xong mà alert còn Fired thì **đừng** kết luận "chưa hết lỗi": nhìn bước 1 (lỗi mới nhất theo
giờ) — không còn dòng 5xx mới là đã xong; chờ email Resolved trong ~25 phút.

## Đã đi thử

2026-09-29, drill bằng `scripts/boom.sh` (197 request `/boom`, 06:42:59–06:51:00Z): đi đủ 6 bước **Xác nhận**,
bảng nguyên nhân dẫn đúng tới dòng "Endpoint lỗi cố ý". Kết quả từng bước: `notes/d22.md` mục "Đi thử runbook";
bằng chứng: `evidence/M11.md` mục 6.

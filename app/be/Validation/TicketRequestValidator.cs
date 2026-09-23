using System.Text.Json;
using OpsBoard.Models;

namespace OpsBoard.Validation;

/// Điều kiện lọc GET /items đã validate + parse xong — repository chỉ còn việc
/// dựng SQL từ đây, không tự parse/validate gì thêm.
public sealed record TicketListFilter(
    TicketStatus? Status,
    TicketSeverity? Severity,
    TicketCategory? Category,
    string? Assignee,
    bool Unassigned,
    string? Q);

/// Chuẩn hoá + kiểm tra input của domain Ticket trước khi service chạm tới
/// repository. Thuần hàm, không phụ thuộc DB — test được không cần dựng DI
/// (giống NodeRequestValidator trước đây).
public static class TicketRequestValidator
{
    public const int TitleMax = 200;
    public const int DescriptionMax = 5000;
    public const int AssigneeMax = 50;
    public const int QMax = 100;
    public const int DefaultLimit = 20;
    public const int MaxLimit = 100;
    public const int BodyMax = 2000;

    /// Validate tạo ticket (prd.md mục 2): title 1–200 sau trim, description
    /// ≤5000 nếu có, assignee 1–50 sau trim nếu có. severity/category mặc định
    /// khi không gửi (request.Severity/Category null).
    public static bool TryValidateCreate(
        CreateTicketRequest request,
        out (string Title, string? Description, TicketSeverity Severity, TicketCategory Category, string? Assignee) values,
        out string? error)
    {
        var title = request.Title.Trim();
        if (title.Length == 0)
        {
            error = "'title' khong duoc rong";
            values = default;
            return false;
        }

        if (title.Length > TitleMax)
        {
            error = $"'title' toi da {TitleMax} ky tu";
            values = default;
            return false;
        }

        string? description = null;
        if (!string.IsNullOrWhiteSpace(request.Description))
        {
            description = request.Description.Trim();
            if (description.Length > DescriptionMax)
            {
                error = $"'description' toi da {DescriptionMax} ky tu";
                values = default;
                return false;
            }
        }

        string? assignee = null;
        if (!string.IsNullOrWhiteSpace(request.Assignee))
        {
            assignee = request.Assignee.Trim();
            if (assignee.Length > AssigneeMax)
            {
                error = $"'assignee' toi da {AssigneeMax} ky tu";
                values = default;
                return false;
            }
        }

        error = null;
        values = (title, description, request.Severity ?? TicketSeverity.Medium, request.Category ?? TicketCategory.Other, assignee);
        return true;
    }

    /// Validate + parse toàn bộ query filter của GET /items. Nhận string? (KHÔNG
    /// để model binding tự xử enum — xem EnumNames.cs và be.md mục 3) rồi tự
    /// parse enum/limit/offset ở đây, một chỗ duy nhất.
    public static bool TryValidateFilter(
        string? status,
        string? severity,
        string? category,
        string? assignee,
        string? unassigned,
        string? q,
        string? limit,
        string? offset,
        out TicketListFilter filter,
        out int limitValue,
        out int offsetValue,
        out string? error)
    {
        filter = default!;
        limitValue = default;
        offsetValue = default;

        // Chuỗi rỗng (param không gửi) = không lọc theo field đó, không phải lỗi.
        TicketStatus? statusValue = null;
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!EnumNames<TicketStatus>.TryParse(status, out var parsed))
            {
                error = $"'status' phai la mot trong: {EnumNames<TicketStatus>.WireValues}";
                return false;
            }

            statusValue = parsed;
        }

        TicketSeverity? severityValue = null;
        if (!string.IsNullOrWhiteSpace(severity))
        {
            if (!EnumNames<TicketSeverity>.TryParse(severity, out var parsed))
            {
                error = $"'severity' phai la mot trong: {EnumNames<TicketSeverity>.WireValues}";
                return false;
            }

            severityValue = parsed;
        }

        TicketCategory? categoryValue = null;
        if (!string.IsNullOrWhiteSpace(category))
        {
            if (!EnumNames<TicketCategory>.TryParse(category, out var parsed))
            {
                error = $"'category' phai la mot trong: {EnumNames<TicketCategory>.WireValues}";
                return false;
            }

            categoryValue = parsed;
        }

        // Chỉ chấp nhận đúng chuỗi "true" (sau trim) — mọi giá trị khác coi như
        // không bật cờ này, giống cách unassigned=false/1/yes... không được định
        // nghĩa trong hợp đồng.
        var isUnassigned = (unassigned?.Trim() ?? string.Empty) == "true";
        var assigneeValue = string.IsNullOrWhiteSpace(assignee) ? null : assignee.Trim();

        if (isUnassigned && assigneeValue is not null)
        {
            error = "khong the dung 'unassigned=true' cung luc voi 'assignee'";
            return false;
        }

        string? qEscaped = null;
        if (!string.IsNullOrEmpty(q))
        {
            if (q.Length > QMax)
            {
                error = $"'q' toi da {QMax} ky tu";
                return false;
            }

            // Escape '\' TRƯỚC — nếu escape % hay _ trước thì các '\' mới sinh ra
            // (từ %/_ ) sẽ bị escape lại lần nữa ở bước escape '\' sau đó.
            qEscaped = q.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
        }

        limitValue = DefaultLimit;
        if (!string.IsNullOrWhiteSpace(limit))
        {
            if (!int.TryParse(limit.Trim(), out limitValue) || limitValue <= 0)
            {
                error = "'limit' phai la so nguyen duong";
                return false;
            }

            // ĐIỂM MƠ HỒ trong spec: api-spec.md/prd.md nói "tối đa 100" nhưng
            // không nói rõ hành vi khi client gửi limit > 100 — kẹp về 100 hay
            // từ chối? Chọn TỪ CHỐI (400) để nhất quán với cách xử lý 'q' quá dài
            // (cũng từ chối, không tự cắt) thay vì âm thầm đổi ý client. Ghi rõ ở
            // đây để Lead quyết định có cần sửa api-spec.md không.
            if (limitValue > MaxLimit)
            {
                error = $"'limit' toi da {MaxLimit}";
                return false;
            }
        }

        offsetValue = 0;
        if (!string.IsNullOrWhiteSpace(offset))
        {
            if (!int.TryParse(offset.Trim(), out offsetValue) || offsetValue < 0)
            {
                error = "'offset' phai la so nguyen khong am";
                return false;
            }
        }

        error = null;
        filter = new TicketListFilter(statusValue, severityValue, categoryValue, assigneeValue, isUnassigned, qEscaped);
        return true;
    }

    /// Validate PATCH /items/{id} (be.md BE-3). Title (nếu gửi): 1–200 sau
    /// trim như lúc tạo. Description/Assignee (nếu gửi) phân biệt VẮNG MẶT vs
    /// GỬI NULL qua JsonElement (không nullable) — xem UpdateTicketRequest và
    /// TryReadNullableString bên dưới. Severity/Category không cần validate ở
    /// đây: JsonStringEnumConverter đã tự chặn enum sai lúc deserialize body,
    /// giống CreateTicketRequest.
    public static bool TryValidateUpdate(
        UpdateTicketRequest request,
        out (string? Title,
            bool DescriptionChanged, string? Description,
            TicketSeverity? Severity,
            TicketCategory? Category,
            bool AssigneeChanged, string? Assignee) values,
        out string? error)
    {
        values = default;

        // Client gửi 'status' trong PATCH field thường (dù string/null/số gì
        // cũng vậy) là sai chỗ — đặt ở ĐẦU hàm để báo ngay, không cần biết
        // các field khác có hợp lệ hay không (api-spec.md, mục PATCH /items/{id}).
        if (request.Status.ValueKind != JsonValueKind.Undefined)
        {
            error = "khong doi 'status' o day, dung PATCH /items/{id}/status";
            return false;
        }

        string? title = null;
        if (request.Title is not null)
        {
            title = request.Title.Trim();
            if (title.Length == 0)
            {
                error = "'title' khong duoc rong";
                return false;
            }

            if (title.Length > TitleMax)
            {
                error = $"'title' toi da {TitleMax} ky tu";
                return false;
            }
        }

        if (!TryReadNullableString(request.Description, "description", DescriptionMax, out var descriptionChanged, out var description, out error))
        {
            return false;
        }

        if (!TryReadNullableString(request.Assignee, "assignee", AssigneeMax, out var assigneeChanged, out var assignee, out error))
        {
            return false;
        }

        error = null;
        values = (title, descriptionChanged, description, request.Severity, request.Category, assigneeChanged, assignee);
        return true;
    }

    /// Validate PATCH /items/{id}/status. Status khai JsonElement (không
    /// nullable, xem ChangeTicketStatusRequest) nên tự phân biệt vắng mặt
    /// (ValueKind.Undefined) / null tường minh (ValueKind.Null) / sai kiểu /
    /// sai giá trị ở đây, thay vì để model binding âm thầm gán
    /// default(TicketStatus) = Open cho field thiếu.
    public static bool TryValidateStatusChange(
        ChangeTicketStatusRequest request, out TicketStatus status, out string? error)
    {
        status = default;

        if (request.Status.ValueKind == JsonValueKind.Undefined || request.Status.ValueKind == JsonValueKind.Null)
        {
            error = "thieu 'status'";
            return false;
        }

        if (request.Status.ValueKind != JsonValueKind.String)
        {
            error = "'status' phai la chuoi";
            return false;
        }

        if (!EnumNames<TicketStatus>.TryParse(request.Status.GetString(), out status))
        {
            error = $"'status' phai la mot trong: {EnumNames<TicketStatus>.WireValues}";
            return false;
        }

        error = null;
        return true;
    }

    /// Validate POST /items/{id}/comments (be.md BE-4). Body 1–2000 ký tự sau
    /// trim: rỗng sau trim (kể cả toàn khoảng trắng) bị coi là thiếu nội dung,
    /// giống cách title bị từ chối khi rỗng sau trim.
    public static bool TryValidateComment(CreateCommentRequest request, out string body, out string? error)
    {
        body = string.Empty;

        var trimmed = request.Body.Trim();
        if (trimmed.Length == 0)
        {
            error = "'body' khong duoc rong";
            return false;
        }

        if (trimmed.Length > BodyMax)
        {
            error = $"'body' toi da {BodyMax} ky tu";
            return false;
        }

        error = null;
        body = trimmed;
        return true;
    }

    /// Đọc một field JsonElement (không nullable) của PATCH, phân biệt bốn
    /// trường hợp dựa thẳng vào ValueKind:
    /// - ValueKind.Undefined ⇒ field VẮNG MẶT trong JSON body ⇒ changed=false, không đổi.
    /// - ValueKind.Null ⇒ client gửi null TƯỜNG MINH ⇒ changed=true, value=null (xoá).
    /// - ValueKind.String ⇒ trim; rỗng sau trim coi như XOÁ (giống
    ///   IsNullOrWhiteSpace ở TryValidateCreate cho assignee), dài quá → lỗi.
    /// - ValueKind khác (number, bool, object, array) ⇒ lỗi 400.
    private static bool TryReadNullableString(
        JsonElement element, string field, int maxLength, out bool changed, out string? value, out string? error)
    {
        changed = false;
        value = null;
        error = null;

        if (element.ValueKind == JsonValueKind.Undefined)
        {
            return true;
        }

        changed = true;

        if (element.ValueKind == JsonValueKind.Null)
        {
            return true;
        }

        if (element.ValueKind != JsonValueKind.String)
        {
            error = $"'{field}' phai la chuoi hoac null";
            return false;
        }

        var trimmed = element.GetString()!.Trim();
        if (trimmed.Length > maxLength)
        {
            error = $"'{field}' toi da {maxLength} ky tu";
            return false;
        }

        value = trimmed.Length == 0 ? null : trimmed;
        return true;
    }
}

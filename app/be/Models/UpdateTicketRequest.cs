using System.Text.Json;

namespace OpsBoard.Models;

/// Payload thô từ client cho PATCH /items/{id} — CHƯA validate, CHƯA trim.
///
/// Description/Assignee khai kiểu JsonElement KHÔNG nullable (KHÔNG phải
/// string?, KHÔNG phải JsonElement?) để phân biệt "field VẮNG MẶT trong
/// body" với "client gửi null TƯỜNG MINH": khi field vắng mặt,
/// System.Text.Json gán default(JsonElement), có ValueKind ==
/// JsonValueKind.Undefined; khi client gửi null tường minh, ValueKind ==
/// JsonValueKind.Null; khi client gửi giá trị, ValueKind == String (hoặc
/// kiểu khác → lỗi). JsonElement? (Nullable<JsonElement>) KHÔNG dùng được
/// cho việc này: NullableConverter bọc ngoài tự chặn token JSON null và trả
/// thẳng C# null TRƯỚC KHI converter thật của JsonElement chạy, nên cả field
/// vắng mặt lẫn field gửi null tường minh đều cho HasValue == false, không
/// phân biệt được (api-spec.md, mục PATCH /items/{id}).
///
/// Title/Severity/Category KHÔNG cần JsonElement: title luôn bắt buộc có
/// giá trị (gửi null không có nghĩa "xoá title"), severity/category cũng vậy
/// (không có khái niệm "xoá severity") — vắng mặt (null C#) = không đổi là
/// đủ, dùng kiểu thường qua JsonStringEnumConverter như CreateTicketRequest.
///
/// `Status` cũng khai JsonElement KHÔNG nullable, giống Description/Assignee
/// — nhưng KHÔNG phải để phân biệt vắng mặt/null như hai field kia: PATCH
/// /items/{id} này không được sửa status (api-spec.md). Mục đích duy nhất là
/// phát hiện client CÓ gửi field 'status' ở đây (dù giá trị gì) để báo lỗi rõ
/// ràng thay vì âm thầm bỏ qua — xem TicketRequestValidator.TryValidateUpdate.
public sealed record UpdateTicketRequest(
    string? Title,
    JsonElement Description,
    TicketSeverity? Severity,
    TicketCategory? Category,
    JsonElement Assignee,
    JsonElement Status);

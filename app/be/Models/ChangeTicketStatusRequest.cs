using System.Text.Json;

namespace OpsBoard.Models;

/// Payload cho PATCH /items/{id}/status. `Status` khai JsonElement KHÔNG
/// nullable (KHÔNG phải TicketStatus thẳng, KHÔNG phải JsonElement?):
/// TicketStatus là value type, không có khái niệm "thiếu" để framework tự
/// bắt như string Title (reference type) — cơ chế implicit-required của
/// [ApiController] chỉ áp cho reference type non-nullable. Field vắng mặt sẽ
/// âm thầm deserialize thành default(enum) = Open thay vì báo lỗi. Dùng
/// JsonElement (không nullable) + TryValidateStatusChange (giống pattern
/// Description/Assignee ở UpdateTicketRequest) để tự phân biệt vắng mặt
/// (ValueKind.Undefined) / null tường minh (ValueKind.Null) / sai kiểu / sai
/// giá trị, trả 400 rõ ràng. JsonElement? không dùng được ở đây vì
/// NullableConverter bọc ngoài chặn token null trước khi tới converter thật
/// của JsonElement, khiến vắng mặt và null tường minh không phân biệt được.
public sealed record ChangeTicketStatusRequest(JsonElement Status);

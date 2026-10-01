using OpsBoard.Models;

namespace OpsBoard.Validation;

/// Trạng thái đích ĐÃ TÍNH XONG cho một lần UPDATE tickets — service quyết
/// nghiệp vụ rồi đưa nguyên khối này cho repository ghi, repository không tự
/// quyết field nào đổi (be.md BE-3, mẫu UpdateAsync).
///
/// Title/Severity/Category null = KHÔNG đổi cột đó trong SET.
/// DescriptionChanged/AssigneeChanged/ResolvedAtChanged = false nghĩa là
/// KHÔNG đổi cột đó; true = đổi, KỂ CẢ khi giá trị mới đi kèm là null (xoá).
public sealed record TicketUpdate(
    string? Title,
    bool DescriptionChanged, string? Description,
    TicketSeverity? Severity,
    TicketCategory? Category,
    bool AssigneeChanged, string? Assignee,
    TicketStatus? Status,
    bool ResolvedAtChanged, DateTime? ResolvedAt,
    // Review 30/09 #5: tự gán assignee khi chuyển in_progress phải kèm điều
    // kiện "assignee vẫn trống" trong CÙNG câu UPDATE — nếu không, một PATCH
    // field gán người khác chen vào giữa lúc đọc và lúc ghi sẽ bị ghi đè và
    // activity ghi sai from_value. Mặc định false: đường PATCH field không đổi.
    bool RequireAssigneeNull = false);

/// Một dòng lịch sử cần ghi trong CÙNG transaction với UPDATE ở trên.
public sealed record ActivityWrite(ActivityAction Action, string? FromValue, string? ToValue);

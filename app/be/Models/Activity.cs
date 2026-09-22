namespace OpsBoard.Models;

/// Entity — đúng một dòng của bảng `activities` (xem docs/docs_app/database-schema.md).
/// `activities` chỉ ghi thêm, không sửa/xoá — là nhật ký kiểm toán.
public sealed record Activity(
    long Id,
    long TicketId,
    string Actor,
    ActivityAction Action,
    string? FromValue,
    string? ToValue,
    DateTime CreatedAt);

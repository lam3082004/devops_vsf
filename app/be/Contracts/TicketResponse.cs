using OpsBoard.Models;

namespace OpsBoard.Contracts;

/// DTO trả ra ngoài cho một ticket — KHÔNG trả entity Ticket thẳng ra HTTP
/// (app/be/CLAUDE.md, mục Contracts/). Tên field snake_case do
/// PropertyNamingPolicy tự chuyển từ PascalCase (xem LoadResponse làm mẫu),
/// không cần tự đặt tên snake_case ở đây.
public sealed record TicketResponse(
    long Id,
    string Title,
    string? Description,
    TicketSeverity Severity,
    TicketCategory Category,
    TicketStatus Status,
    string Reporter,
    string? Assignee,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? ResolvedAt)
{
    /// Dùng lại được từ cả list và create — chỗ duy nhất ánh xạ entity → DTO.
    public static TicketResponse FromEntity(Ticket ticket) => new(
        ticket.Id,
        ticket.Title,
        ticket.Description,
        ticket.Severity,
        ticket.Category,
        ticket.Status,
        ticket.Reporter,
        ticket.Assignee,
        ticket.CreatedAt,
        ticket.UpdatedAt,
        ticket.ResolvedAt);
}

/// Response cho GET /items — snake_case tự sinh: items, total, limit, offset.
/// `Total` là tổng SAU KHI lọc (COUNT(*) riêng, cùng điều kiện WHERE), không
/// phải Items.Count sau khi đã cắt limit/offset.
public sealed record TicketListResponse(IReadOnlyList<TicketResponse> Items, int Total, int Limit, int Offset);

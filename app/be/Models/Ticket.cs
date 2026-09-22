namespace OpsBoard.Models;

/// Entity — đúng một dòng của bảng `tickets` (xem docs/docs_app/database-schema.md).
public sealed record Ticket(
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
    DateTime? ResolvedAt);

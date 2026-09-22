namespace OpsBoard.Models;

/// Entity — đúng một dòng của bảng `comments` (xem docs/docs_app/database-schema.md).
/// Không có `updated_at`: không sửa/xoá bình luận được (PRD US-06).
public sealed record Comment(long Id, long TicketId, string Author, string Body, DateTime CreatedAt);

using OpsBoard.Models;
using OpsBoard.Validation;

namespace OpsBoard.Repositories;

/// Truy cập dữ liệu THUẦN TUÝ — không validate, không quyết định response.
/// Ném exception nguyên bản của MySqlConnector khi DB lỗi; ai gọi tự quyết
/// định biến nó thành gì (xem DatabaseExceptionFilter).
public interface ITicketRepository
{
    Task<(IReadOnlyList<Ticket> Items, int Total)> ListAsync(
        TicketListFilter filter, int limit, int offset, CancellationToken ct);

    Task<Ticket> CreateAsync(
        string title,
        string? description,
        TicketSeverity severity,
        TicketCategory category,
        string reporter,
        string? assignee,
        CancellationToken ct);

    Task<Ticket?> GetByIdAsync(long id, CancellationToken ct);

    /// Tăng dần theo created_at (rồi id để ổn định thứ tự khi cùng giây) —
    /// api-spec.md, mục GET /items/{id}.
    Task<IReadOnlyList<Activity>> ListActivitiesAsync(long ticketId, CancellationToken ct);

    /// Một method = một transaction (be.md BE-3): UPDATE tickets (chỉ cột nào
    /// thực sự đổi) + INSERT từng activity + đọc lại ticket, tất cả trong
    /// cùng một tx. `expectedStatus` khác null là precondition CAS chống
    /// TOCTOU (đường PATCH status, truyền trạng thái HIỆN TẠI đã đọc được);
    /// null nghĩa là không có precondition (đường PATCH field thường). Trả
    /// về null (KHÔNG throw) khi điều kiện WHERE không còn khớp — service map
    /// null này thành 409 (status-change) hoặc 404 (field-update).
    Task<Ticket?> UpdateAsync(
        long id,
        TicketUpdate update,
        IReadOnlyList<ActivityWrite> activities,
        TicketStatus? expectedStatus,
        string actor,
        CancellationToken ct);

    /// Tăng dần theo created_at (rồi id để ổn định thứ tự khi cùng giây) —
    /// api-spec.md, mục Comment.
    Task<IReadOnlyList<Comment>> ListCommentsAsync(long ticketId, CancellationToken ct);

    /// Không transaction: chỉ một bảng, không kèm activity. Đọc lại row vừa
    /// tạo để lấy created_at thật do MySQL tự điền, giống CreateAsync(Ticket).
    /// Gọi hàm này KHI VÀ CHỈ KHI ticket đã được xác nhận tồn tại (service lo
    /// việc đó) — nếu không, INSERT vi phạm fk_comments_ticket sẽ ném
    /// exception, DatabaseExceptionFilter biến thành 503 thay vì 404.
    Task<Comment> CreateCommentAsync(long ticketId, string author, string body, CancellationToken ct);

    /// Số liệu thô cho GET /stats — chưa map "đủ 4 key mặc định 0" (việc đó ở
    /// StatsResponse.BuildByStatus/BuildBySeverity, hàm thuần test được).
    Task<TicketStatsRaw> GetStatsAsync(CancellationToken ct);
}

/// Kết quả thô của GET /stats trước khi map sang StatsResponse.
public sealed record TicketStatsRaw(
    IReadOnlyDictionary<TicketStatus, int> ByStatus,
    IReadOnlyDictionary<TicketSeverity, int> BySeverity,
    int Total,
    int OpenCritical,
    long? AvgResolutionMinutes);

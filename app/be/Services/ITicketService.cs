using OpsBoard.Common;
using OpsBoard.Contracts;
using OpsBoard.Models;

namespace OpsBoard.Services;

public interface ITicketService
{
    Task<Result<TicketListResponse>> ListAsync(
        string? status,
        string? severity,
        string? category,
        string? assignee,
        string? unassigned,
        string? q,
        string? limit,
        string? offset,
        CancellationToken ct);

    Task<Result<TicketResponse>> CreateAsync(CreateTicketRequest request, string reporter, CancellationToken ct);

    Task<Result<TicketDetailResponse>> GetDetailAsync(long id, CancellationToken ct);

    Task<Result<TicketResponse>> UpdateAsync(long id, UpdateTicketRequest request, string actor, CancellationToken ct);

    Task<Result<TicketResponse>> ChangeStatusAsync(long id, ChangeTicketStatusRequest request, string actor, CancellationToken ct);

    Task<Result<CommentListResponse>> ListCommentsAsync(long ticketId, CancellationToken ct);

    Task<Result<CommentResponse>> CreateCommentAsync(long ticketId, CreateCommentRequest request, string author, CancellationToken ct);
}

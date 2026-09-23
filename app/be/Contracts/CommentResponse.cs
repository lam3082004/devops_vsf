using OpsBoard.Models;

namespace OpsBoard.Contracts;

/// DTO trả ra ngoài cho một bình luận — snake_case tự sinh, giống TicketResponse.
public sealed record CommentResponse(long Id, long TicketId, string Author, string Body, DateTime CreatedAt)
{
    /// Chỗ duy nhất ánh xạ entity → DTO, giống TicketResponse.FromEntity.
    public static CommentResponse FromEntity(Comment comment) => new(
        comment.Id,
        comment.TicketId,
        comment.Author,
        comment.Body,
        comment.CreatedAt);
}

/// Response cho GET /items/{id}/comments — snake_case tự sinh: comments.
public sealed record CommentListResponse(IReadOnlyList<CommentResponse> Comments);

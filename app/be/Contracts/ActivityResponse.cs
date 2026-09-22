using OpsBoard.Models;

namespace OpsBoard.Contracts;

/// DTO trả ra ngoài cho một dòng lịch sử — snake_case tự sinh, giống TicketResponse.
public sealed record ActivityResponse(
    long Id,
    long TicketId,
    string Actor,
    ActivityAction Action,
    string? FromValue,
    string? ToValue,
    DateTime CreatedAt)
{
    /// Chỗ duy nhất ánh xạ entity → DTO, giống TicketResponse.FromEntity.
    public static ActivityResponse FromEntity(Activity activity) => new(
        activity.Id,
        activity.TicketId,
        activity.Actor,
        activity.Action,
        activity.FromValue,
        activity.ToValue,
        activity.CreatedAt);
}

/// Response cho GET /items/{id}: ticket + lịch sử, Activities TĂNG DẦN theo
/// thời gian (api-spec.md). KHÔNG gồm comment — BE-4 mới làm bảng comments,
/// frontend gọi GET /items/{id}/comments riêng.
public sealed record TicketDetailResponse(TicketResponse Ticket, IReadOnlyList<ActivityResponse> Activities);

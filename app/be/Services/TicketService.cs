using OpsBoard.Common;
using OpsBoard.Contracts;
using OpsBoard.Models;
using OpsBoard.Repositories;
using OpsBoard.Validation;

namespace OpsBoard.Services;

/// Nghiệp vụ cho "ticket": validate đầu vào rồi mới gọi repository, map sang
/// DTO trước khi trả ra ngoài. Lỗi DB (exception từ MySqlConnector) KHÔNG bắt
/// ở đây — để nó nổi lên tới DatabaseExceptionFilter (503), tránh lặp lại
/// cùng một khối try/catch ở từng service/controller.
public sealed class TicketService : ITicketService
{
    private readonly ITicketRepository _repository;

    public TicketService(ITicketRepository repository) => _repository = repository;

    public async Task<Result<TicketListResponse>> ListAsync(
        string? status,
        string? severity,
        string? category,
        string? assignee,
        string? unassigned,
        string? q,
        string? limit,
        string? offset,
        CancellationToken ct)
    {
        if (!TicketRequestValidator.TryValidateFilter(
                status, severity, category, assignee, unassigned, q, limit, offset,
                out var filter, out var limitValue, out var offsetValue, out var error))
        {
            return Result<TicketListResponse>.Fail(error!);
        }

        var (items, total) = await _repository.ListAsync(filter, limitValue, offsetValue, ct);
        var responses = items.Select(TicketResponse.FromEntity).ToList();
        return Result<TicketListResponse>.Ok(new TicketListResponse(responses, total, limitValue, offsetValue));
    }

    public async Task<Result<TicketResponse>> CreateAsync(CreateTicketRequest request, string reporter, CancellationToken ct)
    {
        if (!TicketRequestValidator.TryValidateCreate(request, out var values, out var error))
        {
            return Result<TicketResponse>.Fail(error!);
        }

        var ticket = await _repository.CreateAsync(
            values.Title, values.Description, values.Severity, values.Category, reporter, values.Assignee, ct);
        return Result<TicketResponse>.Ok(TicketResponse.FromEntity(ticket));
    }

    public async Task<Result<TicketDetailResponse>> GetDetailAsync(long id, CancellationToken ct)
    {
        var ticket = await _repository.GetByIdAsync(id, ct);
        if (ticket is null)
        {
            return Result<TicketDetailResponse>.NotFound("khong tim thay ticket");
        }

        var activities = await _repository.ListActivitiesAsync(id, ct);
        var response = new TicketDetailResponse(
            TicketResponse.FromEntity(ticket),
            activities.Select(ActivityResponse.FromEntity).ToList());
        return Result<TicketDetailResponse>.Ok(response);
    }

    /// So sánh với ticket HIỆN TẠI đọc từ GetByIdAsync (không phải với payload
    /// thô) — field gửi lên nhưng giống hệt giá trị cũ thì KHÔNG tính là đổi,
    /// không ghi activity (be.md BE-3).
    public async Task<Result<TicketResponse>> UpdateAsync(long id, UpdateTicketRequest request, string actor, CancellationToken ct)
    {
        var current = await _repository.GetByIdAsync(id, ct);
        if (current is null)
        {
            return Result<TicketResponse>.NotFound("khong tim thay ticket");
        }

        if (!TicketRequestValidator.TryValidateUpdate(request, out var values, out var error))
        {
            return Result<TicketResponse>.Fail(error!);
        }

        var activities = new List<ActivityWrite>();

        string? newTitle = null;
        if (values.Title is not null && values.Title != current.Title)
        {
            newTitle = values.Title;
            // title_changed/description_changed: from_value/to_value luôn
            // null — cột chỉ VARCHAR(200), description tới 5000 ký tự
            // (api-spec.md).
            activities.Add(new ActivityWrite(ActivityAction.TitleChanged, null, null));
        }

        var descriptionChanged = false;
        string? newDescription = null;
        if (values.DescriptionChanged && values.Description != current.Description)
        {
            descriptionChanged = true;
            newDescription = values.Description;
            activities.Add(new ActivityWrite(ActivityAction.DescriptionChanged, null, null));
        }

        TicketSeverity? newSeverity = null;
        if (values.Severity is { } severity && severity != current.Severity)
        {
            newSeverity = severity;
            activities.Add(new ActivityWrite(
                ActivityAction.SeverityChanged,
                EnumNames<TicketSeverity>.ToWire(current.Severity),
                EnumNames<TicketSeverity>.ToWire(severity)));
        }

        TicketCategory? newCategory = null;
        if (values.Category is { } category && category != current.Category)
        {
            newCategory = category;
            activities.Add(new ActivityWrite(
                ActivityAction.CategoryChanged,
                EnumNames<TicketCategory>.ToWire(current.Category),
                EnumNames<TicketCategory>.ToWire(category)));
        }

        var assigneeChanged = false;
        string? newAssignee = null;
        if (values.AssigneeChanged && values.Assignee != current.Assignee)
        {
            assigneeChanged = true;
            newAssignee = values.Assignee;
            activities.Add(new ActivityWrite(ActivityAction.AssigneeChanged, current.Assignee, values.Assignee));
        }

        var update = new TicketUpdate(
            newTitle,
            descriptionChanged, newDescription,
            newSeverity,
            newCategory,
            assigneeChanged, newAssignee,
            Status: null,
            ResolvedAtChanged: false, ResolvedAt: null);

        // expectedStatus null: đường PATCH field không có precondition CAS —
        // chỉ status-change mới cần chống TOCTOU trên chính cột status.
        var updated = await _repository.UpdateAsync(id, update, activities, expectedStatus: null, actor, ct);
        if (updated is null)
        {
            // Bất thường (ticket biến mất giữa hai bước) — NotFound là lựa
            // chọn an toàn (be.md BE-3).
            return Result<TicketResponse>.NotFound("khong tim thay ticket");
        }

        return Result<TicketResponse>.Ok(TicketResponse.FromEntity(updated));
    }

    public async Task<Result<TicketResponse>> ChangeStatusAsync(long id, ChangeTicketStatusRequest request, string actor, CancellationToken ct)
    {
        var current = await _repository.GetByIdAsync(id, ct);
        if (current is null)
        {
            return Result<TicketResponse>.NotFound("khong tim thay ticket");
        }

        if (!TicketRequestValidator.TryValidateStatusChange(request, out var target, out var validationError))
        {
            return Result<TicketResponse>.Fail(validationError!);
        }

        if (!TicketStatusTransition.IsValid(current.Status, target))
        {
            // Định dạng ĐÚNG NGUYÊN VĂN có dấu cách quanh "->" — api-spec.md
            // cho ví dụ chính xác "open -> resolved khong hop le".
            var reason = $"{EnumNames<TicketStatus>.ToWire(current.Status)} -> {EnumNames<TicketStatus>.ToWire(target)} khong hop le";
            return Result<TicketResponse>.Conflict(reason);
        }

        var activities = new List<ActivityWrite>
        {
            new(ActivityAction.StatusChanged, EnumNames<TicketStatus>.ToWire(current.Status), EnumNames<TicketStatus>.ToWire(target)),
        };

        var resolvedAtChanged = false;
        DateTime? resolvedAt = null;

        if (target == TicketStatus.Resolved)
        {
            resolvedAtChanged = true;
            resolvedAt = DateTime.UtcNow;
        }
        else if (current.Status == TicketStatus.Resolved && target == TicketStatus.InProgress)
        {
            // Mở lại từ resolved → xoá resolved_at. CHỈ trường hợp này mới xoá.
            resolvedAtChanged = true;
            resolvedAt = null;
        }

        var assigneeChanged = false;
        string? newAssignee = null;
        if (target == TicketStatus.InProgress && current.Assignee is null)
        {
            // Sang in_progress (dù từ open hay từ resolved) mà assignee đang
            // trống → gán actor. Đã có assignee thì giữ nguyên.
            assigneeChanged = true;
            newAssignee = actor;
            activities.Add(new ActivityWrite(ActivityAction.AssigneeChanged, null, actor));
        }

        var update = new TicketUpdate(
            Title: null,
            DescriptionChanged: false, Description: null,
            Severity: null,
            Category: null,
            AssigneeChanged: assigneeChanged, Assignee: newAssignee,
            Status: target,
            ResolvedAtChanged: resolvedAtChanged, ResolvedAt: resolvedAt,
            RequireAssigneeNull: assigneeChanged);

        // expectedStatus = trạng thái HIỆN TẠI đã đọc được — chống TOCTOU
        // giữa lúc đọc current ở trên và lúc ghi.
        var updated = await _repository.UpdateAsync(id, update, activities, expectedStatus: current.Status, actor, ct);
        if (updated is null)
        {
            return Result<TicketResponse>.Conflict("ticket vua bi doi boi nguoi khac (trang thai hoac assignee), thu lai");
        }

        return Result<TicketResponse>.Ok(TicketResponse.FromEntity(updated));
    }

    /// Kiểm ticket tồn tại trước (api-spec.md: "Ticket không tồn tại → 404"),
    /// giống mọi action khác trong class này (GetByIdAsync trước).
    public async Task<Result<CommentListResponse>> ListCommentsAsync(long ticketId, CancellationToken ct)
    {
        var ticket = await _repository.GetByIdAsync(ticketId, ct);
        if (ticket is null)
        {
            return Result<CommentListResponse>.NotFound("khong tim thay ticket");
        }

        var comments = await _repository.ListCommentsAsync(ticketId, ct);
        return Result<CommentListResponse>.Ok(new CommentListResponse(comments.Select(CommentResponse.FromEntity).ToList()));
    }

    /// BẪY: PHẢI kiểm ticket tồn tại TRƯỚC KHI gọi CreateCommentAsync của
    /// repository — nếu không, INSERT vi phạm fk_comments_ticket (ticket_id
    /// không tồn tại) ném exception, DatabaseExceptionFilter biến thành 503
    /// thay vì 404 đúng nghĩa.
    public async Task<Result<CommentResponse>> CreateCommentAsync(long ticketId, CreateCommentRequest request, string author, CancellationToken ct)
    {
        var ticket = await _repository.GetByIdAsync(ticketId, ct);
        if (ticket is null)
        {
            return Result<CommentResponse>.NotFound("khong tim thay ticket");
        }

        if (!TicketRequestValidator.TryValidateComment(request, out var body, out var error))
        {
            return Result<CommentResponse>.Fail(error!);
        }

        var comment = await _repository.CreateCommentAsync(ticketId, author, body, ct);
        return Result<CommentResponse>.Ok(CommentResponse.FromEntity(comment));
    }
}

using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;
using OpsBoard.Filters;
using OpsBoard.Models;
using OpsBoard.Services;

namespace OpsBoard.Controllers;

[ApiController]
public sealed class ItemsController : ApiControllerBase
{
    private readonly ITicketService _ticketService;

    public ItemsController(ITicketService ticketService) => _ticketService = ticketService;

    /// Nhận toàn bộ filter dưới dạng string? rồi để validator tự parse —
    /// KHÔNG để MVC tự bind enum (query string đi qua Enum.Parse ignoreCase,
    /// lệch với JsonStringEnumConverter — xem EnumNames.cs).
    [HttpGet("/items")]
    // 503 đã khai ở ApiControllerBase (kế thừa), không lặp lại ở đây.
    [ProducesResponseType(typeof(TicketListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> List(
        [FromQuery] string? status,
        [FromQuery] string? severity,
        [FromQuery] string? category,
        [FromQuery] string? assignee,
        [FromQuery] string? unassigned,
        [FromQuery] string? q,
        [FromQuery] string? limit,
        [FromQuery] string? offset,
        CancellationToken ct)
    {
        var result = await _ticketService.ListAsync(
            status, severity, category, assignee, unassigned, q, limit, offset, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result);
    }

    [HttpPost("/items")]
    [ProducesResponseType(typeof(TicketResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateTicketRequest payload, CancellationToken ct)
    {
        var reporter = UserNameFilter.Require(HttpContext);
        var result = await _ticketService.CreateAsync(payload, reporter, ct);
        return result.IsSuccess
            ? StatusCode(StatusCodes.Status201Created, result.Value)
            : Failure(result);
    }

    [HttpGet("/items/{id:long}")]
    [ProducesResponseType(typeof(TicketDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDetail(long id, CancellationToken ct)
    {
        var result = await _ticketService.GetDetailAsync(id, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result);
    }

    [HttpPatch("/items/{id:long}")]
    [ProducesResponseType(typeof(TicketResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(long id, [FromBody] UpdateTicketRequest payload, CancellationToken ct)
    {
        var actor = UserNameFilter.Require(HttpContext);
        var result = await _ticketService.UpdateAsync(id, payload, actor, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result);
    }

    [HttpPatch("/items/{id:long}/status")]
    [ProducesResponseType(typeof(TicketResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ChangeStatus(long id, [FromBody] ChangeTicketStatusRequest payload, CancellationToken ct)
    {
        var actor = UserNameFilter.Require(HttpContext);
        var result = await _ticketService.ChangeStatusAsync(id, payload, actor, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result);
    }

    [HttpGet("/items/{id:long}/comments")]
    [ProducesResponseType(typeof(CommentListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ListComments(long id, CancellationToken ct)
    {
        var result = await _ticketService.ListCommentsAsync(id, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result);
    }

    [HttpPost("/items/{id:long}/comments")]
    [ProducesResponseType(typeof(CommentResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CreateComment(long id, [FromBody] CreateCommentRequest payload, CancellationToken ct)
    {
        var author = UserNameFilter.Require(HttpContext);
        var result = await _ticketService.CreateCommentAsync(id, payload, author, ct);
        return result.IsSuccess
            ? StatusCode(StatusCodes.Status201Created, result.Value)
            : Failure(result);
    }
}

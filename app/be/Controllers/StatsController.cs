using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;
using OpsBoard.Services;

namespace OpsBoard.Controllers;

/// Endpoint độc lập, không phải sub-resource của /items. KHÔNG cần
/// ApiControllerBase — /stats không có case lỗi nghiệp vụ nào để Failure()
/// xử lý; DB lỗi vẫn tự thành 503 qua DatabaseExceptionFilter như mọi action
/// khác.
[ApiController]
public sealed class StatsController : ControllerBase
{
    private readonly IStatsService _statsService;

    public StatsController(IStatsService statsService) => _statsService = statsService;

    [HttpGet("/stats")]
    // Không kế thừa ApiControllerBase (xem comment trên lớp) nên không có sẵn 503
    // từ đó — khai trực tiếp ở đây, DatabaseExceptionFilter vẫn áp dụng vì filter
    // đăng ký toàn cục ở ApiSetup, không phụ thuộc base class.
    [ProducesResponseType(typeof(StatsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Get(CancellationToken ct) => Ok(await _statsService.GetAsync(ct));
}

using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;
using OpsBoard.Services;

namespace OpsBoard.Controllers;

[ApiController]
public sealed class HealthController : ControllerBase
{
    private readonly IHealthService _healthService;

    public HealthController(IHealthService healthService) => _healthService = healthService;

    /// Sẵn sàng nhận traffic hay chưa: có ping được DB không. 503 khi DB lỗi
    /// để warm-up của slot swap từ chối bản mới (D17).
    [HttpGet("/health")]
    // 503 vẫn là HealthResponse (không phải ErrorResponse): HealthService.CheckAsync
    // tự bắt lỗi và trả false, không bao giờ ném ra ngoài nên DatabaseExceptionFilter
    // không chạm vào nhánh này.
    [ProducesResponseType(typeof(HealthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(HealthResponse), StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Get()
    {
        var healthy = await _healthService.CheckAsync();
        return healthy
            ? Ok(new HealthResponse("ok", "ok"))
            : StatusCode(StatusCodes.Status503ServiceUnavailable, new HealthResponse("degraded", "error"));
    }
}

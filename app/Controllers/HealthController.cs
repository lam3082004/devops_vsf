using Microsoft.AspNetCore.Mvc;
using NodeRegistry.Contracts;
using NodeRegistry.Services;

namespace NodeRegistry.Controllers;

[ApiController]
public sealed class HealthController : ControllerBase
{
    private readonly IHealthService _healthService;

    public HealthController(IHealthService healthService) => _healthService = healthService;

    /// Sẵn sàng nhận traffic hay chưa: có ping được DB không. 503 khi DB lỗi
    /// để warm-up của slot swap từ chối bản mới (D17).
    [HttpGet("/health")]
    public async Task<IActionResult> Get()
    {
        var healthy = await _healthService.CheckAsync();
        return healthy
            ? Ok(new HealthResponse("ok", "ok"))
            : StatusCode(StatusCodes.Status503ServiceUnavailable, new HealthResponse("degraded", "error"));
    }
}

using Microsoft.AspNetCore.Mvc;
using NodeRegistry.Contracts;
using NodeRegistry.Services;

namespace NodeRegistry.Controllers;

[ApiController]
public sealed class LoadController : ControllerBase
{
    private readonly ILoadService _loadService;

    public LoadController(ILoadService loadService) => _loadService = loadService;

    /// Đốt CPU đúng `seconds` giây để chứng minh autoscale (M7).
    [HttpGet("/load")]
    public async Task<IActionResult> Get([FromQuery] string? seconds)
    {
        var result = await _loadService.RunAsync(seconds);
        if (!result.IsSuccess)
        {
            return BadRequest(new ErrorResponse("bad_request", Reason: result.Error));
        }

        return Ok(result.Value);
    }
}

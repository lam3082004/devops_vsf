using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;
using OpsBoard.Services;

namespace OpsBoard.Controllers;

[ApiController]
public sealed class LoadController : ControllerBase
{
    private readonly ILoadService _loadService;

    public LoadController(ILoadService loadService) => _loadService = loadService;

    /// Đốt CPU đúng `seconds` giây để chứng minh autoscale (M7).
    [HttpGet("/load")]
    // /load không chạm DB nên không có 503 (khác các controller kế thừa
    // ApiControllerBase) — bảng mã lỗi trong docs/docs_app/api-spec.md cũng
    // không liệt kê 503 cho endpoint này.
    [ProducesResponseType(typeof(LoadResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
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

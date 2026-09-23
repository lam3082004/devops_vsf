using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;

namespace OpsBoard.Controllers;

/// Không có service riêng: /boom không có nghiệp vụ gì ngoài log + trả 500,
/// thêm một lớp Service chỉ để bọc 3 dòng là thừa.
[ApiController]
public sealed class BoomController : ControllerBase
{
    private readonly IAppLogger _logger;

    public BoomController(IAppLogger logger) => _logger = logger;

    /// Lỗi cố ý để chứng minh alert 5xx (M11). Ghi log level error kèm chi
    /// tiết trong MỘT event, và tiến trình phải sống tiếp.
    [HttpGet("/boom")]
    // Chỉ một nhánh: luôn 500, không có đường thành công.
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status500InternalServerError)]
    public IActionResult Get()
    {
        const string detail = "loi co y tu /boom de kiem thu alert va logging";
        _logger.Error(
            "endpoint /boom nem loi co y",
            ("event", "boom"), ("error", "intentional_failure"), ("detail", detail));
        return StatusCode(StatusCodes.Status500InternalServerError, new ErrorResponse("boom", Detail: detail));
    }
}

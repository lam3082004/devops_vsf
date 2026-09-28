using Microsoft.AspNetCore.Mvc;
using OpsBoard.Common;
using OpsBoard.Contracts;

namespace OpsBoard.Controllers;

/// Không có service riêng: /boom không có nghiệp vụ gì ngoài ném lỗi, thêm một
/// lớp Service chỉ để bọc một dòng là thừa.
[ApiController]
public sealed class BoomController : ControllerBase
{
    /// Lỗi cố ý để chứng minh alert 5xx (M11) và exception trong App Insights (D20).
    /// Ném exception thật; BoomExceptionFilter log level error trong MỘT event và
    /// trả 500 `boom` — tiến trình sống tiếp.
    [HttpGet("/boom")]
    // Chỉ một nhánh: luôn 500, không có đường thành công.
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status500InternalServerError)]
    public IActionResult Get() =>
        throw new BoomException("loi co y tu /boom de kiem thu alert va logging");
}

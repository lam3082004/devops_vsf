using Microsoft.AspNetCore.Mvc;
using OpsBoard.Common;
using OpsBoard.Contracts;

namespace OpsBoard.Controllers;

/// Ánh xạ Result thất bại → mã HTTP, gom về một chỗ để mọi controller trả lỗi
/// giống hệt nhau (docs/docs_app/api-spec.md, bảng mã lỗi).
// Khai 503 một lần ở đây (kế thừa xuống mọi action của lớp con): mọi controller
// kế thừa ApiControllerBase đều đi qua DatabaseExceptionFilter (đăng ký toàn cục
// trong ApiSetup.AddOpsBoard), nên khỏi lặp lại attribute này trên 7 action của
// ItemsController.
[ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status503ServiceUnavailable)]
public abstract class ApiControllerBase : ControllerBase
{
    protected IActionResult Failure<T>(Result<T> result) => result.Kind switch
    {
        // 404 không kèm reason — giống hệt 404 của MapFallback, để client không
        // phải phân biệt "route không có" với "id không có".
        ErrorKind.NotFound => NotFound(new ErrorResponse("not_found")),
        ErrorKind.Conflict => Conflict(new ErrorResponse("invalid_transition", Reason: result.Error)),
        _ => BadRequest(new ErrorResponse("bad_request", Reason: result.Error)),
    };
}

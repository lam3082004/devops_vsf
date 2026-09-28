using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using OpsBoard.Common;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;

namespace OpsBoard.Filters;

/// Biến BoomException thành 500 `boom` đúng api-spec.md, log level error trong MỘT
/// event, và gắn exception vào span của request để App Insights ghi vào bảng
/// exceptions (Failures → Exceptions). Tiến trình sống tiếp.
///
/// Phải tự AddException: exception đã được filter xử lý thì instrumentation của
/// ASP.NET Core không còn thấy nó là exception chưa xử lý.
public sealed class BoomExceptionFilter : IExceptionFilter
{
    private readonly IAppLogger _logger;

    public BoomExceptionFilter(IAppLogger logger) => _logger = logger;

    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not BoomException boom)
        {
            return;
        }

        _logger.Error(
            "endpoint /boom nem loi co y",
            ("event", "boom"), ("error", "intentional_failure"), ("detail", boom.Message));

        Activity.Current?.AddException(boom);
        Activity.Current?.SetStatus(ActivityStatusCode.Error, boom.Message);

        context.Result = new ObjectResult(new ErrorResponse("boom", Detail: boom.Message))
        {
            StatusCode = StatusCodes.Status500InternalServerError,
        };
        context.ExceptionHandled = true;
    }
}

using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using NodeRegistry.Contracts;
using NodeRegistry.Infrastructure;

namespace NodeRegistry.Filters;

/// Bắt MỌI exception chưa xử lý từ action của controller và biến nó thành
/// 503 database_unavailable — tương đương hàm db_error() dùng lặp lại ở bản
/// Rust, nhưng gom về một chỗ thay vì try/catch trong từng action. Trong app
/// này, mọi lỗi không mong đợi từ action đều là lỗi chạm DB (repository là
/// nơi duy nhất có thể throw), nên bắt rộng là hợp lý — nếu app phình to hơn,
/// tách riêng theo loại exception (MySqlException) trước khi bắt Exception chung.
public sealed class DatabaseExceptionFilter : IExceptionFilter
{
    private readonly IAppLogger _logger;

    public DatabaseExceptionFilter(IAppLogger logger) => _logger = logger;

    public void OnException(ExceptionContext context)
    {
        var path = context.HttpContext.Request.Path.Value ?? "unknown";
        _logger.Error(
            "thao tac DB that bai",
            ("event", "db_error"), ("path", path), ("error", context.Exception.Message));

        context.Result = new ObjectResult(new ErrorResponse("database_unavailable"))
        {
            StatusCode = StatusCodes.Status503ServiceUnavailable,
        };
        context.ExceptionHandled = true;
    }
}

using System.Diagnostics;
using NodeRegistry.Infrastructure;

namespace NodeRegistry.Middleware;

/// Một dòng JSON cho mỗi request: method, path, status, thời gian, request_id.
/// Middleware quy ước (constructor nhận RequestDelegate + service singleton,
/// InvokeAsync nhận HttpContext) — đăng ký qua app.UseMiddleware<T>().
public sealed class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IAppLogger _logger;

    public RequestLoggingMiddleware(RequestDelegate next, IAppLogger logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var requestId = Guid.NewGuid().ToString();
        var stopwatch = Stopwatch.StartNew();

        await _next(context);

        _logger.Info(
            "request",
            ("event", "request"),
            ("method", context.Request.Method),
            ("path", context.Request.Path.Value ?? ""),
            ("status", context.Response.StatusCode),
            ("duration_ms", stopwatch.ElapsedMilliseconds),
            ("request_id", requestId));
    }
}

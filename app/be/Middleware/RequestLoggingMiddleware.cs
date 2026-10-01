using System.Diagnostics;
using OpsBoard.Infrastructure;

namespace OpsBoard.Middleware;

/// Một dòng JSON cho mỗi request: method, path, status, thời gian, request_id,
/// trace_id, span_id.
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
        var failed = false;

        // Review 30/09 #11: exception thoát khỏi MVC filter (lỗi ghi response, lỗi middleware
        // sau) từng làm MẤT dòng log request → 5xx đó không có trace_id trong KQL. finally đảm
        // bảo luôn có một dòng; exception vẫn được ném tiếp cho host xử lý (không nuốt).
        try
        {
            await _next(context);
        }
        catch
        {
            failed = true;
            throw;
        }
        finally
        {
            Log(context, requestId, stopwatch, failed);
        }
    }

    private void Log(HttpContext context, string requestId, Stopwatch stopwatch, bool failed)
    {
        _logger.Info(
            "request",
            ("event", "request"),
            ("method", context.Request.Method),
            ("path", context.Request.Path.Value ?? ""),
            // Response chưa kịp đặt mã khi exception thoát ra (vẫn 200 mặc định) → ghi 500,
            // đúng mã host sẽ trả.
            ("status", failed && !context.Response.HasStarted ? 500 : context.Response.StatusCode),
            ("duration_ms", stopwatch.ElapsedMilliseconds),
            ("request_id", requestId),
            // Đi từ alert → KQL → đúng request phải dựa vào trace_id, không phải
            // request_id (request_id chỉ sống trong process này). TraceIdMiddleware
            // đặt giá trị vào Items trước khi tới đây.
            ("trace_id", context.Items[TraceIdMiddleware.ItemKey] as string ?? ""),
            // span_id của request trong trace — trùng id của dòng requests trong App
            // Insights. Rỗng khi không có Activity (telemetry tắt: test, CI, local).
            ("span_id", Activity.Current?.SpanId.ToHexString() ?? ""));
    }
}

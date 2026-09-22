using System.Diagnostics;

namespace OpsBoard.Middleware;

/// Gắn trace id của request vào header X-Trace-Id và vào HttpContext.Items để
/// RequestLoggingMiddleware log cùng một giá trị.
///
/// Nguồn trace id, theo thứ tự ưu tiên:
///   1. Activity.Current — có giá trị khi CÓ listener (OpenTelemetry ở D20).
///      Đừng tin là luôn có: ASP.NET Core chỉ tạo Activity cho request khi có
///      listener, mà app này gọi Logging.ClearProviders() nên bình thường là null.
///      Đã kiểm bằng test MoiResponse_CoHeaderTraceId.
///   2. Header traceparent (W3C) do frontend gửi sang — đây là thứ nối chặng
///      fe → be thành một trace duy nhất.
///   3. Sinh ngẫu nhiên, cho request gọi thẳng vào backend (curl, probe).
///
/// Đặt TRƯỚC RequestLoggingMiddleware trong pipeline (ApiSetup.UseOpsBoard).
public sealed class TraceIdMiddleware
{
    public const string HeaderName = "X-Trace-Id";
    public const string ItemKey = "trace_id";

    private readonly RequestDelegate _next;

    public TraceIdMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        var traceId = ResolveTraceId(context);
        context.Items[ItemKey] = traceId;

        // Gắn lúc bắt đầu gửi response: sau khi body đã chảy đi thì không thêm
        // header được nữa.
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[HeaderName] = traceId;
            return Task.CompletedTask;
        });

        await _next(context);
    }

    private static string ResolveTraceId(HttpContext context)
    {
        var current = Activity.Current?.TraceId;
        if (current is { } activityTraceId && activityTraceId != default)
        {
            return activityTraceId.ToHexString();
        }

        if (TryReadTraceParent(context.Request.Headers.TraceParent.ToString(), out var inherited))
        {
            return inherited;
        }

        return ActivityTraceId.CreateRandom().ToHexString();
    }

    /// traceparent = "00-<32 hex trace-id>-<16 hex span-id>-<2 hex flags>".
    /// Chỉ lấy phần trace-id; span-id của chặng trước không liên quan tới log ở đây.
    /// Trace-id toàn số 0 là giá trị không hợp lệ theo chuẩn W3C.
    private static bool TryReadTraceParent(string? header, out string traceId)
    {
        traceId = string.Empty;
        if (string.IsNullOrEmpty(header))
        {
            return false;
        }

        var parts = header.Split('-');
        if (parts.Length < 4 || parts[1].Length != 32 || parts[1].All(c => c == '0'))
        {
            return false;
        }

        if (!parts[1].All(Uri.IsHexDigit))
        {
            return false;
        }

        traceId = parts[1].ToLowerInvariant();
        return true;
    }
}

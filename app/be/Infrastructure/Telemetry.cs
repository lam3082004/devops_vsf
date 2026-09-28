using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Instrumentation.AspNetCore;
using OpenTelemetry.Logs;
using OpenTelemetry.Trace;

namespace OpsBoard.Infrastructure;

/// Distributed tracing gửi sang Application Insights (D20, notes/d20.md quyết định A, D, E).
///
/// Chỉ bật khi có APPLICATIONINSIGHTS_CONNECTION_STRING: test, CI và chạy local không có
/// biến này, và distro Azure Monitor không có connection string thì ném lỗi lúc khởi động.
///
/// Bật lên thì ASP.NET Core tạo Activity cho mỗi request và tự đọc header traceparent đến,
/// nên TraceIdMiddleware lấy trace id từ Activity.Current: X-Trace-Id (header) = trace_id
/// (log JSON) = operation_Id (App Insights) là cùng một giá trị.
public static class Telemetry
{
    /// Probe và poll (health check của App Service, scripts/m2-poll.sh) chiếm gần hết lưu
    /// lượng mà không mang thông tin trace — bỏ khỏi trace để ingest không vượt cap của
    /// workspace (quyết định E). Request vẫn có trace id và vẫn được log JSON như cũ.
    private static readonly string[] UntracedPaths = ["/health", "/version"];

    /// ActivitySource mà MySqlConnector 2.x tự phát cho mỗi lệnh SQL.
    private const string MySqlConnectorSource = "MySqlConnector";

    public static void AddOpsBoardTelemetry(this WebApplicationBuilder builder, Config config, IAppLogger logger)
    {
        var connectionString = config.AppInsightsConnectionString;
        if (connectionString is null)
        {
            logger.Info("khong co connection string, tat telemetry", ("event", "telemetry_disabled"));
            return;
        }

        // Tham chiếu Key Vault chưa resolve: tắt telemetry và cảnh báo, KHÔNG thoát như
        // DB_PASSWORD — mất trace không đáng để làm sập app đang phục vụ người dùng.
        if (Config.IsUnresolvedKeyVault(connectionString))
        {
            logger.Warn(
                "APPLICATIONINSIGHTS_CONNECTION_STRING van la tham chieu Key Vault chua resolve, tat telemetry",
                ("event", "telemetry_unresolved"));
            return;
        }

        builder.Services.AddOpenTelemetry()
            .UseAzureMonitor(options =>
            {
                options.ConnectionString = connectionString;
                // Distro từ 1.5.0 mặc định giới hạn 5 trace/giây. Lưu lượng người dùng thật
                // của app này thấp hơn nhiều, nên giữ 100% (xem CHANGELOG của package).
                options.SamplingRatio = 1.0F;
                options.TracesPerSecond = null;
                // Không ghi telemetry chờ gửi lại xuống đĩa container: filesystem đó mất
                // theo mỗi lần restart/swap, và image chiseled không cần thêm chỗ ghi.
                options.DisableOfflineStorage = true;
            })
            .WithTracing(tracing => tracing
                .AddSource(MySqlConnectorSource)
                // Thay sampler 100% của distro: span con (lệnh SQL) có cha LOCAL không được
                // sample — tức request /health, /version đã bị Filter bên dưới bỏ — thì bỏ
                // theo; không có nó thì lệnh ping DB của /health vẫn ra thành dependency mồ
                // côi. Mọi trường hợp khác giữ 100% (quyết định E), kể cả request đến mang
                // traceparent cờ "không sample" (-00) từ client bên ngoài.
                .SetSampler(new ParentBasedSampler(
                    rootSampler: new AlwaysOnSampler(),
                    remoteParentSampled: new AlwaysOnSampler(),
                    remoteParentNotSampled: new AlwaysOnSampler(),
                    localParentSampled: new AlwaysOnSampler(),
                    localParentNotSampled: new AlwaysOffSampler())));

        builder.Services.Configure<AspNetCoreTraceInstrumentationOptions>(options =>
        {
            var previous = options.Filter;
            options.Filter = context => ShouldTrace(context) && (previous?.Invoke(context) ?? true);
        });

        // Distro cũng thêm logging provider của OpenTelemetry. Log của app đi JSON ra stdout
        // rồi vào Log Analytics (D21) — gửi thêm qua đây là ingest hai lần cùng một thứ.
        builder.Logging.AddFilter<OpenTelemetryLoggerProvider>(null, LogLevel.None);

        logger.Info("bat telemetry Azure Monitor", ("event", "telemetry_enabled"));
    }

    public static bool ShouldTrace(HttpContext context) =>
        !UntracedPaths.Contains(context.Request.Path.Value ?? "", StringComparer.OrdinalIgnoreCase);
}

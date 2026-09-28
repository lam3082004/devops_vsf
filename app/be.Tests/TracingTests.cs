using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MySqlConnector;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;
using OpsBoard.Middleware;
using Xunit;

namespace OpsBoard.Tests;

/// Hành vi khi CÓ listener cho Activity — tình huống production khi bật OpenTelemetry
/// (D20). Một ActivityListener lấy mẫu mọi thứ đóng vai OpenTelemetry mà không cần
/// exporter hay connection string: ASP.NET Core tạo Activity cho request và tự đọc
/// traceparent đến, đúng như lúc distro Azure Monitor chạy.
public class TracingTests : IAsyncLifetime
{
    private const string TraceId = "4bf92f3577b34da6a3ce929d0e0e4736";

    private readonly CapturingLogger _logger = new();
    private ActivityListener _listener = null!;
    private WebApplication _app = null!;
    private HttpClient _client = null!;
    private MySqlDataSource _dataSource = null!;

    public async Task InitializeAsync()
    {
        _listener = new ActivityListener
        {
            ShouldListenTo = source => source.Name == "Microsoft.AspNetCore",
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllDataAndRecorded,
        };
        ActivitySource.AddActivityListener(_listener);

        var config = new Config(
            Port: 0, DbHost: "127.0.0.1", DbPort: 3306, DbName: "test",
            DbUser: "test", DbPassword: "test", DbTls: false, LoadMaxSeconds: 60);
        _dataSource = MySqlDataSourceFactory.Create(config);

        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Logging.ClearProviders();
        builder.Services
            .AddOpsBoard(config, _logger, new AppMetadata("test-sha"), _dataSource)
            .AddApplicationPart(typeof(OpsBoard.Controllers.HealthController).Assembly);

        _app = builder.Build();
        _app.UseOpsBoard();
        await _app.StartAsync();

        var address = _app.Services.GetRequiredService<IServer>()
            .Features.Get<IServerAddressesFeature>()!.Addresses.First();
        _client = new HttpClient { BaseAddress = new Uri(address) };
    }

    public async Task DisposeAsync()
    {
        _client.Dispose();
        await _app.StopAsync();
        _dataSource.Dispose();
        _listener.Dispose();
    }

    [Fact]
    public async Task TraceparentDen_XTraceId_BangTraceIdCuaNo()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "/boom");
        request.Headers.Add("traceparent", $"00-{TraceId}-00f067aa0ba902b7-01");

        var response = await _client.SendAsync(request);

        Assert.Equal(TraceId, Assert.Single(response.Headers.GetValues(TraceIdMiddleware.HeaderName)));
    }

    [Fact]
    public async Task LogRequest_CoTraceIdVaSpanIdCuaActivity()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "/version");
        request.Headers.Add("traceparent", $"00-{TraceId}-00f067aa0ba902b7-01");

        await _client.SendAsync(request);

        var line = Assert.Single(_logger.Lines, l => l.Fields.GetValueOrDefault("event") as string == "request");
        Assert.Equal(TraceId, line.Fields["trace_id"]);
        var spanId = Assert.IsType<string>(line.Fields["span_id"]);
        Assert.Equal(16, spanId.Length);
        // Span của server là span MỚI, không phải span-id của chặng trước trong traceparent.
        Assert.NotEqual("00f067aa0ba902b7", spanId);
    }

    [Fact]
    public async Task Boom_LogMotEventError_VaGanExceptionVaoSpan()
    {
        // Trace id riêng: các lớp test khác chạy song song cũng gọi /boom, listener thấy
        // Activity của MỌI host trong process.
        const string boomTraceId = "0af7651916cd43dd8448eb211c80319c";
        Activity? requestActivity = null;
        using var capture = new ActivityListener
        {
            ShouldListenTo = source => source.Name == "Microsoft.AspNetCore",
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllDataAndRecorded,
            ActivityStopped = activity =>
            {
                if (activity.TraceId.ToHexString() == boomTraceId)
                {
                    requestActivity = activity;
                }
            },
        };
        ActivitySource.AddActivityListener(capture);

        using var request = new HttpRequestMessage(HttpMethod.Get, "/boom");
        request.Headers.Add("traceparent", $"00-{boomTraceId}-00f067aa0ba902b7-01");
        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        var boom = Assert.Single(_logger.Lines, l => l.Fields.GetValueOrDefault("event") as string == "boom");
        Assert.Equal("error", boom.Level);
        Assert.NotNull(requestActivity);
        Assert.Equal(ActivityStatusCode.Error, requestActivity!.Status);
        var exception = Assert.Single(requestActivity.Events, e => e.Name == "exception");
        Assert.Contains(exception.Tags, t => t.Key == "exception.type" && (t.Value as string ?? "").EndsWith("BoomException"));
    }

    [Theory]
    [InlineData("/health", false)]
    [InlineData("/version", false)]
    [InlineData("/VERSION", false)]
    [InlineData("/items", true)]
    [InlineData("/boom", true)]
    public void ChiBoProbeKhoiTrace(string path, bool expected)
    {
        var context = new DefaultHttpContext();
        context.Request.Path = path;
        Assert.Equal(expected, Telemetry.ShouldTrace(context));
    }

    private sealed record LogLine(string Level, string Message, Dictionary<string, object?> Fields);

    private sealed class CapturingLogger : IAppLogger
    {
        private readonly ConcurrentQueue<LogLine> _lines = new();

        public IReadOnlyCollection<LogLine> Lines => _lines.ToArray();

        public void Info(string message, params (string Key, object? Value)[] fields) => Add("info", message, fields);

        public void Warn(string message, params (string Key, object? Value)[] fields) => Add("warn", message, fields);

        public void Error(string message, params (string Key, object? Value)[] fields) => Add("error", message, fields);

        private void Add(string level, string message, (string Key, object? Value)[] fields) =>
            _lines.Enqueue(new LogLine(level, message, fields.ToDictionary(f => f.Key, f => f.Value)));
    }
}

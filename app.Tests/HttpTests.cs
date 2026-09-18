using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MySqlConnector;
using NodeRegistry.Contracts;
using NodeRegistry.Filters;
using NodeRegistry.Infrastructure;
using NodeRegistry.Middleware;
using NodeRegistry.Repositories;
using NodeRegistry.Services;
using Xunit;

namespace NodeRegistry.Tests;

/// Dựng lại đúng pipeline DI của Program.cs (đăng ký service, filter,
/// middleware, JSON options) nhưng KHÔNG cần MySQL thật: các endpoint kiểm ở
/// đây (/version, /load, /boom, 404) không chạm DB. MySqlDataSource là lazy
/// nên tạo được mà không cần kết nối.
public class HttpTests : IAsyncLifetime
{
    private WebApplication _app = null!;
    private HttpClient _client = null!;
    private MySqlDataSource _dataSource = null!;

    public async Task InitializeAsync()
    {
        var config = new Config(
            Port: 0, DbHost: "127.0.0.1", DbPort: 3306, DbName: "test",
            DbUser: "test", DbPassword: "test", DbTls: false, LoadMaxSeconds: 60);
        _dataSource = MySqlDataSourceFactory.Create(config);

        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Logging.ClearProviders();

        builder.Services.AddSingleton(config);
        builder.Services.AddSingleton<IAppLogger>(new JsonConsoleLogger());
        builder.Services.AddSingleton(new AppMetadata("test-sha"));
        builder.Services.AddSingleton(_dataSource);
        builder.Services.AddScoped<INodeRepository, NodeRepository>();
        builder.Services.AddScoped<IDatabaseRepository, DatabaseRepository>();
        builder.Services.AddScoped<INodeService, NodeService>();
        builder.Services.AddScoped<IHealthService, HealthService>();
        builder.Services.AddScoped<ILoadService, LoadService>();

        builder.Services
            .AddControllers(options => options.Filters.Add<DatabaseExceptionFilter>())
            // Entry assembly ở đây là app.Tests, không phải NodeRegistry — MVC chỉ
            // tự quét controller trong entry assembly nên phải khai rõ assembly
            // chứa controller thật (khác Program.cs, nơi NodeRegistry chính là entry).
            .AddApplicationPart(typeof(NodeRegistry.Controllers.HealthController).Assembly)
            .AddJsonOptions(options => ConfigureJson(options.JsonSerializerOptions));
        builder.Services.ConfigureHttpJsonOptions(options => ConfigureJson(options.SerializerOptions));

        _app = builder.Build();
        _app.UseMiddleware<RequestLoggingMiddleware>();
        _app.MapControllers();
        _app.MapFallback(() =>
            Results.Json(new ErrorResponse("not_found"), statusCode: StatusCodes.Status404NotFound));

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
    }

    private static void ConfigureJson(JsonSerializerOptions options)
    {
        options.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
        options.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    }

    [Fact]
    public async Task Version_TraVeSha()
    {
        var response = await _client.GetAsync("/version");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("test-sha", body);
    }

    [Theory]
    [InlineData("/load")]
    [InlineData("/load?seconds=abc")]
    [InlineData("/load?seconds=0")]
    [InlineData("/load?seconds=61")]
    public async Task Load_TuChoiThamSoSai(string path)
    {
        var response = await _client.GetAsync(path);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("bad_request", body);
    }

    [Fact]
    public async Task Boom_Tra500_VaKhongLamChetApp()
    {
        var boom = await _client.GetAsync("/boom");
        Assert.Equal(HttpStatusCode.InternalServerError, boom.StatusCode);

        var sau = await _client.GetAsync("/version");
        Assert.Equal(HttpStatusCode.OK, sau.StatusCode);
    }

    [Fact]
    public async Task PathLa_Tra404Json()
    {
        var response = await _client.GetAsync("/khong-co-that");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("not_found", body);
    }
}

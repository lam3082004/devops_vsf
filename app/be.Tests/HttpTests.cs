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
using OpsBoard.Filters;
using OpsBoard.Infrastructure;
using OpsBoard.Middleware;
using Xunit;

namespace OpsBoard.Tests;

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

        // Dùng ĐÚNG ApiSetup của app: DI, JSON, filter, pipeline đều là một bản
        // duy nhất nên test không thể xanh trong khi production cấu hình khác.
        builder.Services
            .AddOpsBoard(config, new JsonConsoleLogger(), new AppMetadata("test-sha"), _dataSource)
            // Entry assembly ở đây là app.Tests, không phải OpsBoard — MVC chỉ
            // tự quét controller trong entry assembly nên phải khai rõ assembly
            // chứa controller thật (khác Program.cs, nơi OpsBoard chính là entry).
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

    [Fact]
    public async Task MoiResponse_CoHeaderTraceId()
    {
        var response = await _client.GetAsync("/version");

        Assert.True(
            response.Headers.TryGetValues(TraceIdMiddleware.HeaderName, out var values),
            $"thieu header {TraceIdMiddleware.HeaderName}");
        // 32 ký tự hex: đúng độ dài trace id của W3C trace context.
        var traceId = Assert.Single(values);
        Assert.Equal(32, traceId.Length);
    }

    [Fact]
    public async Task ThieuHeaderUserName_ThiPostBiTuChoi()
    {
        var response = await _client.PostAsync("/items", JsonBody("""{"title":"Mot ticket"}"""));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("bad_request", body);
        Assert.Contains(UserNameFilter.HeaderName, body);
    }

    [Fact]
    public async Task UserNameQuaDai_ThiPostBiTuChoi()
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items")
        {
            Content = JsonBody("""{"title":"Mot ticket"}"""),
        };
        request.Headers.Add(UserNameFilter.HeaderName, new string('a', UserNameFilter.MaxLength + 1));

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("toi da", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task GetKhongCanUserName()
    {
        // Filter chỉ chặn POST/PATCH. /load là GET và không chạm DB nên kiểm được
        // rằng đường đọc vẫn đi qua bình thường khi không có header.
        var response = await _client.GetAsync("/load?seconds=1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task BodyHong_TraErrorResponse_KhongPhaiProblemDetails()
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items")
        {
            Content = JsonBody("{ khong phai json }"),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "Lam");

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("bad_request", body);
        // ProblemDetails có "title"/"traceId"; hợp đồng của app chỉ có error/reason.
        Assert.DoesNotContain("\"title\"", body);
    }

    [Fact]
    public async Task ThieuFieldBatBuoc_TenFieldTraVeLaSnakeCase()
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items")
        {
            Content = JsonBody("{}"),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "Lam");

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        // Key của ModelState là tên property C# ("Title"); client phải thấy tên trong
        // hợp đồng API, không phải tên nội bộ.
        Assert.Contains("'title'", body);
        Assert.DoesNotContain("'Title'", body);
    }

    [Fact]
    public async Task ThieuBody_ItemsIdComments_LoiChiRoBody_KhongPhaiId()
    {
        // Khoá bug ApiSetup.ConfigureApiBehavior: route /items/{id}/comments bind
        // 'id' (từ route, luôn hợp lệ) TRƯỚC 'body' (từ JSON, thiếu) nên
        // ModelState.Keys.FirstOrDefault() từng lấy nhầm 'id'. Không cần DB thật —
        // request bị chặn ở tầng model-binding trước khi chạm repository.
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items/1/comments")
        {
            Content = JsonBody("{}"),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "Lam");

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("'body'", body);
        Assert.DoesNotContain("'id'", body);
    }

    [Fact]
    public async Task SaiKieuEnum_ItemsIdPatch_KhongLoTenThamSoAction()
    {
        // PO phát hiện: JsonException lúc parse enum sai kiểu ({"severity":123},
        // allowIntegerValues: false) không mang JSON path nên MVC gán lỗi cho
        // 'payload' — tên tham số C# của Update(long id, [FromBody]
        // UpdateTicketRequest payload, ...), không phải tên field hợp đồng.
        using var request = new HttpRequestMessage(HttpMethod.Patch, "/items/1")
        {
            Content = JsonBody("""{"severity":123}"""),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "Lam");

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("payload", body);
        Assert.Contains("body khong hop le", body);
    }

    [Fact]
    public async Task Stats_KhongCoDbThat_Tra503KhongPhai404()
    {
        // Không có MySQL thật ở host test (DbHost 127.0.0.1:3306 không ai lắng
        // nghe) — GetStatsAsync ném exception kết nối, DatabaseExceptionFilter
        // bắt và trả 503. Test này khoá: route /stats có đăng ký (không 404) và
        // DI đủ (không 500 do thiếu IStatsService).
        var response = await _client.GetAsync("/stats");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Comments_KhongCoDbThat_Tra503KhongPhai404()
    {
        var response = await _client.GetAsync("/items/1/comments");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    private static StringContent JsonBody(string json) =>
        new(json, System.Text.Encoding.UTF8, "application/json");
}

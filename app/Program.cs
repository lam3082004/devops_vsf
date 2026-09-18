using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NodeRegistry;
using NodeRegistry.Contracts;
using NodeRegistry.Filters;
using NodeRegistry.Infrastructure;
using NodeRegistry.Middleware;
using NodeRegistry.Repositories;
using NodeRegistry.Services;

// SHA của commit, nhúng lúc build qua MSBuild property GitSha (xem NodeRegistry.csproj,
// Target EmbedGitSha). Build local không truyền gì thì là "dev".
var gitSha = BuildInfo.GitSha;

// Logger dựng TRƯỚC container DI: cần log ngay cả khi config sai và app
// thoát trước lúc builder.Build(). Cùng instance này được đăng ký vào DI
// bên dưới để controller/middleware/filter inject được.
var logger = new JsonConsoleLogger();

Config config;
try
{
    config = Config.FromEnvironment();
}
catch (ConfigException ex)
{
    // Chỉ log tên biến và lý do (đã đảm bảo ở Config) — không bao giờ log giá trị.
    logger.Error(ex.Message, ("event", "config_error"));
    Environment.Exit(1);
    return;
}

logger.Info(
    "app khoi dong",
    ("event", "startup"), ("sha", gitSha), ("port", config.Port),
    ("db_host", config.DbHost), ("db_name", config.DbName), ("db_tls", config.DbTls),
    ("load_max_seconds", config.LoadMaxSeconds));

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls($"http://0.0.0.0:{config.Port}");
// JsonConsoleLogger thay hoàn toàn logging framework mặc định (nó ghi
// multi-line, không phải 1 dòng JSON/record như yêu cầu).
builder.Logging.ClearProviders();
// Kestrel (khác axum) có timeout chờ shutdown mặc định — kéo dài nó ra để một
// request /load đang đốt CPU tới LoadMaxSeconds vẫn kịp trả lời trước khi bị cắt.
builder.Services.Configure<HostOptions>(o =>
    o.ShutdownTimeout = TimeSpan.FromSeconds(config.LoadMaxSeconds + 5));

static void ConfigureJson(JsonSerializerOptions options)
{
    options.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    // Giữ đúng hợp đồng cũ: bad_request chỉ có "reason", boom chỉ có "detail",
    // không lòi thêm field null ra ngoài.
    options.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
}

builder.Services.AddSingleton(config);
builder.Services.AddSingleton<IAppLogger>(logger);
builder.Services.AddSingleton(new AppMetadata(gitSha));

var dataSource = MySqlDataSourceFactory.Create(config);
builder.Services.AddSingleton(dataSource);

builder.Services.AddScoped<INodeRepository, NodeRepository>();
builder.Services.AddScoped<IDatabaseRepository, DatabaseRepository>();
builder.Services.AddScoped<INodeService, NodeService>();
builder.Services.AddScoped<IHealthService, HealthService>();
builder.Services.AddScoped<ILoadService, LoadService>();

builder.Services
    .AddControllers(options => options.Filters.Add<DatabaseExceptionFilter>())
    .AddJsonOptions(options => ConfigureJson(options.JsonSerializerOptions));
// MapFallback (404) đi qua minimal API, có bộ JsonOptions riêng với AddJsonOptions
// ở trên — cấu hình cả hai để response giống hệt nhau dù tới từ controller hay không.
builder.Services.ConfigureHttpJsonOptions(options => ConfigureJson(options.SerializerOptions));

// Tạo bảng nếu chưa có, trước khi app nhận request. DB chưa sẵn sàng thì chỉ
// cảnh báo: app vẫn chạy, /health trả 503 cho tới khi DB lên.
try
{
    await new DatabaseRepository(dataSource).EnsureSchemaAsync();
    logger.Info("bang nodes san sang", ("event", "schema_ready"));
}
catch (Exception ex)
{
    logger.Warn(
        "chua tao duoc bang, se thu lai khi co request",
        ("event", "schema_failed"), ("error", ex.Message));
}

var app = builder.Build();

app.UseMiddleware<RequestLoggingMiddleware>();

app.MapControllers();
app.MapFallback(() =>
    Results.Json(new ErrorResponse("not_found"), statusCode: StatusCodes.Status404NotFound));

// Chờ SIGTERM (App Service/Docker gửi khi dừng container) hoặc SIGINT (Ctrl+C).
// Generic Host tự bắt hai tín hiệu này và gọi ApplicationStopping trước khi
// ngừng nhận request mới; không xử lý thì container bị kill cứng sau thời gian
// chờ, request đang dở bị cắt giữa chừng — đúng nguyên nhân gián đoạn ở D2.
app.Lifetime.ApplicationStopping.Register(() =>
    logger.Info(
        "nhan tin hieu dung, ngung nhan request moi va cho request dang do",
        ("event", "shutdown_started")));

app.Lifetime.ApplicationStopped.Register(() =>
{
    // Tới đây: đã ngừng nhận kết nối mới và các request đang dở đã xong.
    dataSource.Dispose();
    logger.Info("dong pool DB, thoat sach", ("event", "shutdown_complete"));
});

logger.Info("san sang nhan request", ("event", "listening"), ("port", config.Port));

await app.RunAsync();

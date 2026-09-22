using System.Reflection;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi;
using OpsBoard;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;
using OpsBoard.Repositories;

// SHA của commit, nhúng lúc build qua MSBuild property GitSha (xem OpsBoard.csproj,
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

var dataSource = MySqlDataSourceFactory.Create(config);

// DI + JSON + hành vi lỗi model binding: khai một chỗ duy nhất (ApiSetup) để host
// test dựng được pipeline y hệt production, không phải chép lại rồi lệch nhau.
builder.Services.AddOpsBoard(config, logger, new AppMetadata(gitSha), dataSource);
builder.Services.AddEndpointsApiExplorer();
// SwaggerDoc + XML comments + header operation filter, không phải AddSwaggerGen()
// trơn: không có [ProducesResponseType] + comment thì Swagger suy được response
// schema nhưng không có mô tả, và X-User-Name (đọc qua IActionFilter, xem
// UserNameFilter) vô hình với reflection của Swashbuckle nếu thiếu operation filter.
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "OpsBoard API",
        Version = "v1",
        Description = "Xem hợp đồng đầy đủ ở docs/docs_app/api-spec.md.",
    });

    // Tên file XML do GenerateDocumentationFile sinh ra khớp AssemblyName
    // (OpsBoard.csproj) — build Release luôn có file này (đã bật CS1591 kèm theo),
    // nhưng vẫn check tồn tại để không vỡ Swagger khi lỡ build thiếu.
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        options.IncludeXmlComments(xmlPath);
    }

    options.OperationFilter<UserNameHeaderOperationFilter>();
});

// Tạo bảng nếu chưa có, trước khi app nhận request. DB chưa sẵn sàng thì chỉ
// cảnh báo: app vẫn chạy, /health trả 503 cho tới khi DB lên.
try
{
    await new DatabaseRepository(dataSource).EnsureSchemaAsync();
    logger.Info("schema san sang", ("event", "schema_ready"));
}
catch (Exception ex)
{
    logger.Warn(
        "chua tao duoc bang, se thu lai khi co request",
        ("event", "schema_failed"), ("error", ex.Message));
}

var app = builder.Build();

// Chỉ bật ở Development (ASPNETCORE_ENVIRONMENT=Development, đặt trong
// app/.env.example và docker-compose.yml). Terraform (D8/D9) không set biến
// này cho Web App → mặc định .NET là Production → Swagger tự tắt trên Azure
// thật, không cần nhớ gỡ thủ công.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseOpsBoard();

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

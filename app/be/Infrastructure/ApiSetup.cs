using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;
using OpsBoard.Contracts;
using OpsBoard.Filters;
using OpsBoard.Middleware;
using OpsBoard.Repositories;
using OpsBoard.Services;

namespace OpsBoard.Infrastructure;

/// Nơi duy nhất mô tả "một host OpsBoard trông như thế nào": DI, JSON, hành vi
/// lỗi model binding, pipeline.
///
/// Vì sao gom lại: trước đây Program.cs và app.Tests/HttpTests.cs chép nhau bốn
/// khối (ConfigureJson, đăng ký DI, AddJsonOptions/ConfigureHttpJsonOptions,
/// middleware + MapFallback). Thêm một service mà quên một bên thì test đỏ theo
/// kiểu rất khó lần, còn bỏ sót ConfigureHttpJsonOptions thì 404 của MapFallback
/// khác 404 của controller mà không ai nhận ra.
public static class ApiSetup
{
    /// Đăng ký toàn bộ service của app. Trả IMvcBuilder để host test còn chain
    /// được AddApplicationPart (entry assembly của nó là app.Tests nên MVC không
    /// tự quét ra controller thật).
    public static IMvcBuilder AddOpsBoard(
        this IServiceCollection services,
        Config config,
        IAppLogger logger,
        AppMetadata metadata,
        MySqlDataSource dataSource)
    {
        services.AddSingleton(config);
        services.AddSingleton(logger);
        services.AddSingleton(metadata);
        services.AddSingleton(dataSource);

        services.AddScoped<ITicketRepository, TicketRepository>();
        services.AddScoped<IDatabaseRepository, DatabaseRepository>();
        services.AddScoped<ITicketService, TicketService>();
        services.AddScoped<IHealthService, HealthService>();
        services.AddScoped<ILoadService, LoadService>();
        services.AddScoped<IStatsService, StatsService>();

        // MapFallback đi qua minimal API, có bộ JsonOptions RIÊNG với AddJsonOptions
        // bên dưới — cấu hình cả hai để response giống hệt nhau dù tới từ controller
        // hay không.
        services.ConfigureHttpJsonOptions(options => ConfigureJson(options.SerializerOptions));

        var mvc = services
            .AddControllers(options =>
            {
                options.Filters.Add<DatabaseExceptionFilter>();
                options.Filters.Add<UserNameFilter>();
            })
            .AddJsonOptions(options => ConfigureJson(options.JsonSerializerOptions));

        // PHẢI đứng SAU AddControllers: AddControllers tự đăng ký một
        // IConfigureOptions<ApiBehaviorOptions> đặt InvalidModelStateResponseFactory
        // về ProblemDetails. Các configure chạy theo thứ tự đăng ký, nên khai trước
        // thì bị MVC ghi đè lại và lỗi model binding lại ra ProblemDetails.
        // Đã kiểm bằng test BodyHong_TraErrorResponse_KhongPhaiProblemDetails.
        services.Configure<ApiBehaviorOptions>(ConfigureApiBehavior);

        return mvc;
    }

    /// Pipeline. Giữ mỏng đúng như trước: không UseRouting/UseAuthentication/UseCors
    /// — app này không có phiên đăng nhập, biên bảo vệ là access restriction của
    /// App Service (docs/docs_app/architecture.md).
    public static void UseOpsBoard(this WebApplication app)
    {
        app.UseMiddleware<TraceIdMiddleware>();
        app.UseMiddleware<RequestLoggingMiddleware>();
        app.MapControllers();
        app.MapFallback(() =>
            Results.Json(new ErrorResponse("not_found"), statusCode: StatusCodes.Status404NotFound));
    }

    public static void ConfigureJson(JsonSerializerOptions options)
    {
        options.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
        // Mặc định GIỮ field null: DTO dữ liệu phải trả đủ field để frontend gõ kiểu
        // được (api-spec.md). ErrorResponse là kiểu duy nhất cần bỏ null và nó tự
        // mang attribute — xem Contracts/Responses.cs.
        options.DefaultIgnoreCondition = JsonIgnoreCondition.Never;
        // Không có converter này thì enum serialize ra SỐ. allowIntegerValues: false
        // để client gửi {"status": 2} bị từ chối thẳng thay vì đoán mò.
        options.Converters.Add(
            new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower, allowIntegerValues: false));
    }

    /// Không có hàm này thì mọi lỗi deserialize (JSON hỏng, sai kiểu, enum lạ) trả
    /// ProblemDetails của ASP.NET Core, lệch hợp đồng "lỗi luôn là ErrorResponse".
    public static void ConfigureApiBehavior(ApiBehaviorOptions options) =>
        options.InvalidModelStateResponseFactory = context =>
        {
            // Chỉ lấy TÊN FIELD từ key ("$.severity" → "severity"). Message gốc của
            // System.Text.Json chứa tên kiểu C# — không đẩy nội bộ ra ngoài.
            //
            // Key có hai dạng: đường dẫn JSON ("$.severity") khi sai kiểu, hoặc TÊN
            // PROPERTY C# ("Title") khi thiếu field bắt buộc. Chuẩn hoá về snake_case
            // để client luôn thấy đúng tên field trong hợp đồng, không phải tên C#.
            //
            // PHẢI lọc lấy entry ĐẦU TIÊN THỰC SỰ CÓ LỖI — ModelState.Keys chứa MỌI
            // key đã bind, kể cả key hợp lệ. Route như /items/{id}/comments bind 'id'
            // (từ route) TRƯỚC 'body' (từ JSON body) nên nếu chỉ lấy Keys.FirstOrDefault()
            // thì 'id' luôn đứng đầu dù nó không hề sai — field báo lỗi bị lấy nhầm tên.
            // Đã kiểm bằng test ThieuBody_ItemsIdComments_LoiChiRoBody_KhongPhaiId.
            //
            // Case thứ ba: JsonException ném ra lúc parse enum sai kiểu (vd
            // {"severity":123} với allowIntegerValues: false) KHÔNG mang JSON path,
            // nên MVC gán lỗi cho key là TÊN THAM SỐ ACTION ("payload" ở
            // Update(long id, [FromBody] UpdateTicketRequest payload, ...)) chứ
            // không phải tên field. Lọc thêm theo parameterNames để không lộ tên
            // tham số C# ra ngoài — PO phát hiện qua PATCH /items/{id}.
            var parameterNames = context.ActionDescriptor.Parameters
                .Select(p => p.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var field = context.ModelState
                .FirstOrDefault(e => e.Value is { Errors.Count: > 0 }).Key?.TrimStart('$', '.');
            var reason = string.IsNullOrEmpty(field) || parameterNames.Contains(field)
                ? "body khong hop le"
                : $"'{JsonNamingPolicy.SnakeCaseLower.ConvertName(field)}' khong hop le";
            return new BadRequestObjectResult(new ErrorResponse("bad_request", Reason: reason));
        };
}

using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using OpsBoard.Contracts;
using OpsBoard.Filters;
using OpsBoard.Infrastructure;
using OpsBoard.Models;
using Xunit;

namespace OpsBoard.Tests;

/// Test tích hợp qua HTTP thật (Kestrel) trỏ vào MySQL thật (TEST_DB_*) —
/// khác HttpTests.cs (không chạm DB). `[Collection("mysql")]` BẮT BUỘC: xUnit
/// chạy song song theo collection, class này và TicketRepositoryTests cùng
/// `DELETE FROM tickets` nên phải chạy tuần tự với nhau (be.md BE-5).
[Collection("mysql")]
public sealed class TicketsApiTests : IAsyncLifetime
{
    private static readonly JsonSerializerOptions JsonOptions = BuildJsonOptions();

    private readonly MySqlFixture _fixture;
    private WebApplication? _app;
    private HttpClient? _client;

    public TicketsApiTests(MySqlFixture fixture) => _fixture = fixture;

    /// Dọn bảng tickets ĐẦU MỖI TEST (comments/activities dọn theo qua FK
    /// ON DELETE CASCADE) rồi dựng một host mới trỏ đúng MySqlDataSource của
    /// fixture — dùng chung ApiSetup như HttpTests.cs nên không thể xanh test
    /// trong khi production cấu hình khác.
    public async Task InitializeAsync()
    {
        if (_fixture.DataSource is null)
        {
            // Không có MySQL thật: mọi [RequiresMySqlFact] trong class này đã
            // bị skip, host không cần dựng.
            return;
        }

        await CleanTicketsAsync();

        var config = new Config(
            Port: 0,
            DbHost: Environment.GetEnvironmentVariable("TEST_DB_HOST") ?? string.Empty,
            DbPort: int.TryParse(Environment.GetEnvironmentVariable("TEST_DB_PORT"), out var port) ? port : 3306,
            DbName: Environment.GetEnvironmentVariable("TEST_DB_NAME") ?? string.Empty,
            DbUser: Environment.GetEnvironmentVariable("TEST_DB_USER") ?? string.Empty,
            DbPassword: Environment.GetEnvironmentVariable("TEST_DB_PASSWORD") ?? string.Empty,
            DbTls: false,
            LoadMaxSeconds: 60);

        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseUrls("http://127.0.0.1:0");
        builder.Logging.ClearProviders();

        builder.Services
            .AddOpsBoard(config, new JsonConsoleLogger(), new AppMetadata("test-sha"), _fixture.DataSource)
            // Entry assembly ở đây là app.Tests — xem HttpTests.cs.
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
        _client?.Dispose();
        if (_app is not null)
        {
            await _app.StopAsync();
        }

        // KHÔNG dispose _fixture.DataSource ở đây — nó sống chung cho cả
        // collection "mysql", MySqlFixture.DisposeAsync lo việc đó.
    }

    [RequiresMySqlFact]
    public async Task Loc_PhanTrang_TotalLaTongSauKhiLoc_LimitOffsetDung()
    {
        for (var i = 0; i < 3; i++)
        {
            await CreateTicketAsync($"Open ticket {i}");
        }

        var wip = await CreateTicketAsync("WIP ticket");
        await ChangeStatusAsync(wip.Id, "in_progress");

        var response = await _client!.GetAsync("/items?status=open&limit=2&offset=1");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var list = await ReadJsonAsync<TicketListResponse>(response);

        // total la SO TICKET OPEN sau khi loc (3), khong phai tong ca bang (4)
        // va khong phai so item con lai sau khi cat limit/offset (2).
        Assert.Equal(3, list.Total);
        Assert.Equal(2, list.Limit);
        Assert.Equal(1, list.Offset);
        Assert.Equal(2, list.Items.Count);
        Assert.All(list.Items, t => Assert.Equal(TicketStatus.Open, t.Status));
    }

    [RequiresMySqlFact]
    public async Task Filter_Q_EscapePhanTram_ChiTraDungTicketChuaKyTuDo()
    {
        // Neu '%' khong duoc escape truoc khi ghep vao LIKE thi q=% se khop
        // MOI ticket (wildcard "tat ca") thay vi chi ticket co ky tu % that.
        await CreateTicketAsync("Disk 100% full");
        await CreateTicketAsync("Disk almost full");
        await CreateTicketAsync("CPU spike");

        var response = await _client!.GetAsync("/items?q=" + Uri.EscapeDataString("%"));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var list = await ReadJsonAsync<TicketListResponse>(response);

        Assert.Equal(1, list.Total);
        Assert.Equal("Disk 100% full", Assert.Single(list.Items).Title);
    }

    [RequiresMySqlFact]
    public async Task ChuyenTrangThai_Resolved_GhiResolvedAt_MoLaiXoaResolvedAt()
    {
        var ticket = await CreateTicketAsync("Se resolved roi mo lai");
        var inProgress = await ChangeStatusAsync(ticket.Id, "in_progress");
        Assert.Null(inProgress.ResolvedAt);

        var resolved = await ChangeStatusAsync(ticket.Id, "resolved");
        Assert.NotNull(resolved.ResolvedAt);

        // resolved -> in_progress la duong "mo lai" duy nhat xoa resolved_at
        // (TicketService.ChangeStatusAsync).
        var reopened = await ChangeStatusAsync(ticket.Id, "in_progress");
        Assert.Null(reopened.ResolvedAt);
    }

    [RequiresMySqlFact]
    public async Task Comments_Post201_DocLaiDuocQuaGet_SapXepTheoCreatedAt()
    {
        var ticket = await CreateTicketAsync("Ticket co comment");

        var first = await CreateCommentAsync(ticket.Id, "Comment dau tien");
        var second = await CreateCommentAsync(ticket.Id, "Comment thu hai");

        var response = await _client!.GetAsync($"/items/{ticket.Id}/comments");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var list = await ReadJsonAsync<CommentListResponse>(response);

        Assert.Equal(2, list.Comments.Count);
        Assert.Equal(first.Id, list.Comments[0].Id);
        Assert.Equal(second.Id, list.Comments[1].Id);
    }

    [RequiresMySqlFact]
    public async Task Comments_TicketKhongTonTai_Tra404_KhongPhai503()
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items/999999999/comments")
        {
            Content = JsonBody(new { body = "noi dung binh luan" }),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);

        // Khong phai 503: ticket khong ton tai PHAI duoc kiem TRUOC KHI insert
        // (be.md BE-4) — neu khong, vi pham fk_comments_ticket se nem
        // exception va DatabaseExceptionFilter bien thanh 503 sai nghia.
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [RequiresMySqlFact]
    public async Task Stats_DemDungTheoStatusVaSeverity_Du4KeyKeCaBang0()
    {
        await CreateTicketAsync("Open critical", severity: "critical");
        await CreateTicketAsync("Open low", severity: "low");
        var wip = await CreateTicketAsync("WIP high", severity: "high");
        await ChangeStatusAsync(wip.Id, "in_progress");

        var response = await _client!.GetAsync("/stats");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var stats = await ReadJsonAsync<StatsResponse>(response);

        Assert.Equal(3, stats.Total);
        Assert.Equal(2, stats.ByStatus.Open);
        Assert.Equal(1, stats.ByStatus.InProgress);
        Assert.Equal(0, stats.ByStatus.Resolved);
        Assert.Equal(0, stats.ByStatus.Closed);
        Assert.Equal(1, stats.BySeverity.Critical);
        Assert.Equal(1, stats.BySeverity.Low);
        Assert.Equal(1, stats.BySeverity.High);
        Assert.Equal(0, stats.BySeverity.Medium);
        Assert.Equal(1, stats.OpenCritical);
    }

    [RequiresMySqlFact]
    public async Task Stats_AvgResolutionMinutes_NullKhiChuaResolved_CoGiaTriKhiDaResolved()
    {
        var ticket = await CreateTicketAsync("Chua resolved");

        var before = await ReadJsonAsync<StatsResponse>(await _client!.GetAsync("/stats"));
        Assert.Null(before.AvgResolutionMinutes);

        await ChangeStatusAsync(ticket.Id, "in_progress");
        await ChangeStatusAsync(ticket.Id, "resolved");

        var after = await ReadJsonAsync<StatsResponse>(await _client!.GetAsync("/stats"));
        Assert.NotNull(after.AvgResolutionMinutes);
        Assert.True(after.AvgResolutionMinutes >= 0);
    }

    [RequiresMySqlFact]
    public async Task GetDetail_KhongTonTai_Tra404()
    {
        var response = await _client!.GetAsync("/items/999999999");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    /// be.md BE-5, bảng "Test tích hợp phải phủ": POST -> 201 + activity
    /// 'created'. CreateTicketAsync (helper) đã tự Assert 201; test này thêm
    /// phần còn thiếu — GHI activity 'created' thật trong DB, đọc lại qua
    /// GET /items/{id} (không phải suy đoán từ code TicketRepository).
    [RequiresMySqlFact]
    public async Task Create_GhiActivityCreated_DocLaiQuaGetDetail()
    {
        var ticket = await CreateTicketAsync("Ticket moi tao");

        var response = await _client!.GetAsync($"/items/{ticket.Id}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detail = await ReadJsonAsync<TicketDetailResponse>(response);

        Assert.Equal(ticket.Id, detail.Ticket.Id);
        var activity = Assert.Single(detail.Activities);
        Assert.Equal(ActivityAction.Created, activity.Action);
    }

    /// be.md BE-3/BE-5: field JsonElement (không nullable) phải phân biệt
    /// VẮNG MẶT (không đổi) với NULL tường minh (xoá giá trị) khi PATCH
    /// /items/{id}. Test thuần (TicketUpdateValidatorTests) đã phủ validator,
    /// test này phủ đường HTTP + DB thật — đúng như be.md yêu cầu, chưa có
    /// test nào trước đây chạm PATCH /items/{id} qua DB thật.
    [RequiresMySqlFact]
    public async Task PatchItem_Assignee_VangMatGiuNguyen_NullTuongMinhXoa()
    {
        var ticket = await CreateTicketAsync("Ticket can gan nguoi");

        var withAssignee = await PatchItemAsync(ticket.Id, new { assignee = "alice" });
        Assert.Equal("alice", withAssignee.Assignee);

        // 'assignee' VANG MAT trong body -> KHONG doi, van con "alice".
        var unchanged = await PatchItemAsync(ticket.Id, new { title = "Ticket can gan nguoi" });
        Assert.Equal("alice", unchanged.Assignee);

        // 'assignee' gui NULL tuong minh -> xoa gia tri.
        var cleared = await PatchItemAsync(ticket.Id, new { assignee = (string?)null });
        Assert.Null(cleared.Assignee);
    }

    /// be.md BE-5, bảng "Test tích hợp phải phủ": status 409. StatusTransitionTests.cs
    /// đã phủ state machine thuần; test này phủ đường HTTP + DB thật, kể cả
    /// nguyên văn 'reason' (api-spec.md).
    [RequiresMySqlFact]
    public async Task ChangeStatus_KhongHopLe_Tra409_KemReason()
    {
        var ticket = await CreateTicketAsync("Ticket dang open");

        using var request = new HttpRequestMessage(HttpMethod.Patch, $"/items/{ticket.Id}/status")
        {
            Content = JsonBody(new { status = "resolved" }),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        var error = await ReadJsonAsync<ErrorResponse>(response);
        Assert.Equal("invalid_transition", error.Error);
        Assert.Equal("open -> resolved khong hop le", error.Reason);
    }

    private async Task CleanTicketsAsync()
    {
        await using var connection = await _fixture.DataSource!.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        // ON DELETE CASCADE don theo comments + activities (DatabaseRepository).
        command.CommandText = "DELETE FROM tickets";
        await command.ExecuteNonQueryAsync();
    }

    private async Task<TicketResponse> CreateTicketAsync(
        string title, string severity = "medium", string category = "other")
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/items")
        {
            Content = JsonBody(new { title, severity, category }),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await ReadJsonAsync<TicketResponse>(response);
    }

    private async Task<TicketResponse> PatchItemAsync(long id, object payload)
    {
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"/items/{id}")
        {
            Content = JsonBody(payload),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await ReadJsonAsync<TicketResponse>(response);
    }

    private async Task<TicketResponse> ChangeStatusAsync(long id, string status)
    {
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"/items/{id}/status")
        {
            Content = JsonBody(new { status }),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await ReadJsonAsync<TicketResponse>(response);
    }

    private async Task<CommentResponse> CreateCommentAsync(long ticketId, string body)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, $"/items/{ticketId}/comments")
        {
            Content = JsonBody(new { body }),
        };
        request.Headers.Add(UserNameFilter.HeaderName, "tester");

        var response = await _client!.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await ReadJsonAsync<CommentResponse>(response);
    }

    /// Tên field của payload đặt sẵn đúng snake_case (title/severity/status/body...)
    /// nên dùng JsonSerializer mặc định (không cần PropertyNamingPolicy) — khác
    /// JsonOptions dùng để ĐỌC response, phải khớp policy của ApiSetup.
    private static StringContent JsonBody(object payload) =>
        new(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

    private static async Task<T> ReadJsonAsync<T>(HttpResponseMessage response)
    {
        var stream = await response.Content.ReadAsStreamAsync();
        return (await JsonSerializer.DeserializeAsync<T>(stream, JsonOptions))!;
    }

    private static JsonSerializerOptions BuildJsonOptions()
    {
        var options = new JsonSerializerOptions();
        ApiSetup.ConfigureJson(options);
        return options;
    }
}

using System.Text.Json;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;
using OpsBoard.Models;
using Xunit;

namespace OpsBoard.Tests;

/// Hợp đồng JSON ở docs/docs_app/api-spec.md, mục "Quy ước chung".
/// Hai quy tắc dễ vỡ âm thầm: enum phải ra CHUỖI (không phải số), và null phải
/// được GIỮ ở DTO dữ liệu nhưng BỎ ở ErrorResponse.
public class JsonContractTests
{
    private static readonly JsonSerializerOptions Options = Tao();

    private static JsonSerializerOptions Tao()
    {
        var options = new JsonSerializerOptions();
        ApiSetup.ConfigureJson(options);
        return options;
    }

    private sealed record ViDuTicket(long Id, TicketStatus Status, TicketSeverity Severity, string? Assignee);

    [Fact]
    public void Enum_SerializeRaChuoiSnakeCase()
    {
        var json = JsonSerializer.Serialize(
            new ViDuTicket(1, TicketStatus.InProgress, TicketSeverity.Critical, null), Options);

        Assert.Contains("\"status\":\"in_progress\"", json);
        Assert.Contains("\"severity\":\"critical\"", json);
        // Nếu thiếu JsonStringEnumConverter thì chỗ này ra số và frontend gõ kiểu sai.
        Assert.DoesNotContain("\"status\":1", json);
    }

    [Fact]
    public void Enum_DocDuocTuChuoi()
    {
        var ticket = JsonSerializer.Deserialize<ViDuTicket>(
            """{"id":1,"status":"resolved","severity":"low","assignee":null}""", Options);

        Assert.NotNull(ticket);
        Assert.Equal(TicketStatus.Resolved, ticket.Status);
    }

    [Fact]
    public void Enum_TuChoiSoNguyen()
    {
        // allowIntegerValues: false — client gửi số thì hỏng thẳng, không đoán mò.
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<ViDuTicket>(
            """{"id":1,"status":2,"severity":"low","assignee":null}""", Options));
    }

    [Fact]
    public void DtoDuLieu_GiuFieldNull()
    {
        var json = JsonSerializer.Serialize(
            new ViDuTicket(1, TicketStatus.Open, TicketSeverity.Low, null), Options);

        // Frontend gõ `assignee: string | null` nên field phải LUÔN có mặt.
        Assert.Contains("\"assignee\":null", json);
    }

    [Fact]
    public void ErrorResponse_BoFieldNull()
    {
        var badRequest = JsonSerializer.Serialize(
            new ErrorResponse("bad_request", Reason: "'title' khong duoc rong"), Options);
        var notFound = JsonSerializer.Serialize(new ErrorResponse("not_found"), Options);

        Assert.Contains("\"reason\"", badRequest);
        Assert.DoesNotContain("\"detail\"", badRequest);
        // not_found chỉ có đúng một field.
        Assert.Equal("""{"error":"not_found"}""", notFound);
    }

    [Fact]
    public void TenField_LaSnakeCase()
    {
        var json = JsonSerializer.Serialize(new LoadResponse(3, 42), Options);

        Assert.Contains("\"burned_seconds\":3", json);
    }

    [Fact]
    public void StatsResponse_AvgResolutionMinutesNull_VanCoMatTrongJson()
    {
        // avg_resolution_minutes la null khi chua ticket nao resolved —
        // DTO du lieu phai GIU field null (api-spec.md, mục GET /stats),
        // khac ErrorResponse.
        var stats = new StatsResponse(
            Total: 57,
            ByStatus: new StatsByStatus(4, 2, 1, 50),
            BySeverity: new StatsBySeverity(20, 25, 9, 3),
            OpenCritical: 3,
            AvgResolutionMinutes: null);

        var json = JsonSerializer.Serialize(stats, Options);

        Assert.Contains("\"avg_resolution_minutes\":null", json);
        Assert.Contains("\"by_status\":", json);
        Assert.Contains("\"in_progress\":2", json);
    }
}

using System.Text.Json;
using OpsBoard.Infrastructure;
using OpsBoard.Models;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// Khoa lai bug da fix o review BE-3: PATCH /items/{id}/status thieu field
/// "status" tung bi am tham deserialize thanh default(TicketStatus) = Open
/// thay vi bao loi. Deserialize tu CHUOI JSON THAT (giong JsonContractTests)
/// qua dung JsonSerializerOptions cua app (ApiSetup.ConfigureJson) — bug goc
/// chi lo ra qua duong nay, dung ChangeTicketStatusRequest bang tay se khong
/// khoa duoc gi ca.
public class ChangeStatusRequestValidationTests
{
    private static readonly JsonSerializerOptions Options = Tao();

    private static JsonSerializerOptions Tao()
    {
        var options = new JsonSerializerOptions();
        ApiSetup.ConfigureJson(options);
        return options;
    }

    private static ChangeTicketStatusRequest Doc(string json) =>
        JsonSerializer.Deserialize<ChangeTicketStatusRequest>(json, Options)!;

    [Fact]
    public void ThieuKeyStatus_TuChoi_KhongDuocNgamDinhOpen()
    {
        // Day la test quan trong nhat: neu ChangeTicketStatusRequest.Status
        // quay lai kieu TicketStatus thuong (khong phai JsonElement?) thi
        // field vang mat trong body se am tham deserialize thanh
        // default(TicketStatus) = Open, ok se la true thay vi false.
        var request = Doc("{}");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out _, out var error);

        // Diem chot cua bug: phai la false. Neu bug tai xuat hien thi day se
        // la true (kem status ngam dinh = Open) va assert nay do.
        Assert.False(ok);
        Assert.Contains("status", error);
    }

    [Fact]
    public void StatusNullTuongMinh_TuChoi()
    {
        var request = Doc("""{"status": null}""");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("status", error);
    }

    [Fact]
    public void StatusLaSo_TuChoi_KhongThrow()
    {
        var request = Doc("""{"status": 2}""");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'status'", error);
    }

    [Fact]
    public void StatusSaiCase_TuChoi()
    {
        var request = Doc("""{"status": "IN_PROGRESS"}""");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'status'", error);
    }

    [Fact]
    public void StatusKhongTonTai_TuChoi()
    {
        var request = Doc("""{"status": "bogus"}""");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'status'", error);
    }

    [Fact]
    public void StatusHopLe_ChapNhan()
    {
        var request = Doc("""{"status": "in_progress"}""");

        var ok = TicketRequestValidator.TryValidateStatusChange(request, out var status, out var error);

        Assert.True(ok);
        Assert.Null(error);
        Assert.Equal(TicketStatus.InProgress, status);
    }
}

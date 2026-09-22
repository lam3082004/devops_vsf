using System.Text.Json;
using OpsBoard.Infrastructure;
using OpsBoard.Models;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// TryValidateUpdate (PATCH /items/{id}, be.md BE-3): description/assignee
/// phan biet VANG MAT (khong doi) vs GUI null (xoa) qua JsonElement? — deserialize
/// tu CHUOI JSON THAT (giong JsonContractTests) de kiem dung duong ValueKind
/// thuc te, khong dung JsonElement? thu cong.
public class TicketUpdateValidatorTests
{
    private static readonly JsonSerializerOptions Options = Tao();

    private static JsonSerializerOptions Tao()
    {
        var options = new JsonSerializerOptions();
        ApiSetup.ConfigureJson(options);
        return options;
    }

    private static UpdateTicketRequest Doc(string json) =>
        JsonSerializer.Deserialize<UpdateTicketRequest>(json, Options)!;

    // ---- description / assignee: vang mat vs null tuong minh ----

    [Fact]
    public void DescriptionVangMat_KhongDoi()
    {
        var request = Doc("{}");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.Null(error);
        Assert.False(values.DescriptionChanged);
        Assert.Null(values.Description);
    }

    [Fact]
    public void AssigneeVangMat_KhongDoi()
    {
        var request = Doc("{}");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.False(values.AssigneeChanged);
        Assert.Null(values.Assignee);
    }

    [Fact]
    public void DescriptionNullTuongMinh_Xoa()
    {
        var request = Doc("""{"description": null}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.Null(error);
        Assert.True(values.DescriptionChanged);
        Assert.Null(values.Description);
    }

    [Fact]
    public void AssigneeNullTuongMinh_Xoa()
    {
        var request = Doc("""{"assignee": null}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.True(values.AssigneeChanged);
        Assert.Null(values.Assignee);
    }

    [Fact]
    public void DescriptionChuoi_TrimVaSetGiaTri()
    {
        var request = Doc("""{"description": "  Mo ta moi  "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.True(values.DescriptionChanged);
        Assert.Equal("Mo ta moi", values.Description);
    }

    [Fact]
    public void AssigneeChuoi_TrimVaSetGiaTri()
    {
        var request = Doc("""{"assignee": "  Lam  "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.True(values.AssigneeChanged);
        Assert.Equal("Lam", values.Assignee);
    }

    [Fact]
    public void DescriptionChuoiRongSauTrim_CoiNhuXoa()
    {
        var request = Doc("""{"description": "   "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.True(values.DescriptionChanged);
        Assert.Null(values.Description);
    }

    [Fact]
    public void AssigneeChuoiRongSauTrim_CoiNhuXoa()
    {
        var request = Doc("""{"assignee": "   "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.True(values.AssigneeChanged);
        Assert.Null(values.Assignee);
    }

    [Fact]
    public void AssigneeQuaDai_Loi()
    {
        var json = $$"""{"assignee": "{{new string('a', TicketRequestValidator.AssigneeMax + 1)}}"}""";
        var request = Doc(json);

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'assignee'", error);
    }

    [Fact]
    public void DescriptionQuaDai_Loi()
    {
        var json = $$"""{"description": "{{new string('a', TicketRequestValidator.DescriptionMax + 1)}}"}""";
        var request = Doc(json);

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'description'", error);
    }

    [Theory]
    [InlineData("""{"description": 123}""")]
    [InlineData("""{"description": true}""")]
    [InlineData("""{"description": [1,2]}""")]
    [InlineData("""{"description": {"a":1}}""")]
    public void DescriptionKieuSai_LoiRoRang_KhongThrow(string json)
    {
        var request = Doc(json);

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'description'", error);
    }

    [Theory]
    [InlineData("""{"assignee": 123}""")]
    [InlineData("""{"assignee": false}""")]
    [InlineData("""{"assignee": [1,2]}""")]
    [InlineData("""{"assignee": {"a":1}}""")]
    public void AssigneeKieuSai_LoiRoRang_KhongThrow(string json)
    {
        var request = Doc(json);

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'assignee'", error);
    }

    // ---- title ----

    [Fact]
    public void TitleVangMat_KhongDoi()
    {
        var request = Doc("{}");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.Null(values.Title);
    }

    [Fact]
    public void TitleRongSauTrim_Loi()
    {
        var request = Doc("""{"title": "   "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'title'", error);
    }

    [Fact]
    public void TitleQuaDai_Loi()
    {
        var json = $$"""{"title": "{{new string('a', TicketRequestValidator.TitleMax + 1)}}"}""";
        var request = Doc(json);

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("'title'", error);
    }

    [Fact]
    public void TitleHopLe_TrimVaSetGiaTri()
    {
        var request = Doc("""{"title": "  Tieu de moi  "}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.Equal("Tieu de moi", values.Title);
    }

    // ---- status: khong duoc doi o day (dung PATCH /items/{id}/status) ----

    [Fact]
    public void StatusCoMat_TuChoi_GoiYDungEndpointStatus()
    {
        var request = Doc("""{"status": "in_progress"}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("PATCH /items/{id}/status", error);
    }

    [Fact]
    public void StatusVangMat_KhongBiChan()
    {
        var request = Doc("""{"title": "Tieu de moi"}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out var values, out var error);

        Assert.True(ok);
        Assert.Null(error);
    }

    [Fact]
    public void StatusNullTuongMinh_TuChoi_GoiYDungEndpointStatus()
    {
        var request = Doc("""{"status": null}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("PATCH /items/{id}/status", error);
    }

    [Fact]
    public void StatusSoNguyen_TuChoi_GoiYDungEndpointStatus()
    {
        var request = Doc("""{"status": 123}""");

        var ok = TicketRequestValidator.TryValidateUpdate(request, out _, out var error);

        Assert.False(ok);
        Assert.Contains("PATCH /items/{id}/status", error);
    }
}

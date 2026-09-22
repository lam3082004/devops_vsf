using OpsBoard.Models;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// TicketRequestValidator là hàm thuần, không chạm DB — test được không cần
/// dựng DI/DB (giống NodesTests trước đây).
public class TicketValidatorTests
{
    // ---- TryValidateCreate ----

    [Fact]
    public void TaoTicket_TitleRong_BiTuChoi()
    {
        var ok = TicketRequestValidator.TryValidateCreate(
            new CreateTicketRequest("   ", null, null, null, null), out _, out var error);
        Assert.False(ok);
        Assert.Equal("'title' khong duoc rong", error);
    }

    [Fact]
    public void TaoTicket_TitleQuaDai_BiTuChoi()
    {
        var request = new CreateTicketRequest(
            new string('a', TicketRequestValidator.TitleMax + 1), null, null, null, null);
        var ok = TicketRequestValidator.TryValidateCreate(request, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'title'", error);
    }

    [Fact]
    public void TaoTicket_DescriptionQuaDai_BiTuChoi()
    {
        var request = new CreateTicketRequest(
            "Tieu de", new string('a', TicketRequestValidator.DescriptionMax + 1), null, null, null);
        var ok = TicketRequestValidator.TryValidateCreate(request, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'description'", error);
    }

    [Fact]
    public void TaoTicket_AssigneeQuaDai_BiTuChoi()
    {
        var request = new CreateTicketRequest(
            "Tieu de", null, null, null, new string('a', TicketRequestValidator.AssigneeMax + 1));
        var ok = TicketRequestValidator.TryValidateCreate(request, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'assignee'", error);
    }

    [Fact]
    public void TaoTicket_DescriptionRong_CoiNhuKhongGui()
    {
        // Khac voi title (bat buoc, rong bi tu choi): description la optional —
        // chuoi rong/toan khoang trang phai duoc coi nhu "khong gui", KHONG
        // phai loi. Khoa lai ranh gioi nay vi TryValidateCreate dung
        // IsNullOrWhiteSpace de quyet dinh, de nham lan voi nhanh cua title.
        var request = new CreateTicketRequest("Tieu de", "   ", null, null, null);
        var ok = TicketRequestValidator.TryValidateCreate(request, out var values, out var error);
        Assert.True(ok);
        Assert.Null(error);
        Assert.Null(values.Description);
    }

    [Fact]
    public void TaoTicket_AssigneeRong_CoiNhuKhongGui()
    {
        // Tuong tu description: assignee rong/toan khoang trang khong bi tu
        // choi, chi bi coi nhu khong gui (assignee = null), khac voi truong
        // hop qua dai (bi tu choi, xem TaoTicket_AssigneeQuaDai_BiTuChoi).
        var request = new CreateTicketRequest("Tieu de", null, null, null, "   ");
        var ok = TicketRequestValidator.TryValidateCreate(request, out var values, out var error);
        Assert.True(ok);
        Assert.Null(error);
        Assert.Null(values.Assignee);
    }

    [Fact]
    public void TaoTicket_KhongGuiSeverityCategory_MacDinhMediumOther()
    {
        var request = new CreateTicketRequest("Tieu de", null, null, null, null);
        var ok = TicketRequestValidator.TryValidateCreate(request, out var values, out _);
        Assert.True(ok);
        Assert.Equal(TicketSeverity.Medium, values.Severity);
        Assert.Equal(TicketCategory.Other, values.Category);
    }

    [Fact]
    public void TaoTicket_GuiSeverityCategory_GiuNguyenGiaTri()
    {
        var request = new CreateTicketRequest("Tieu de", null, TicketSeverity.Critical, TicketCategory.Database, null);
        var ok = TicketRequestValidator.TryValidateCreate(request, out var values, out _);
        Assert.True(ok);
        Assert.Equal(TicketSeverity.Critical, values.Severity);
        Assert.Equal(TicketCategory.Database, values.Category);
    }

    [Fact]
    public void TaoTicket_TrimTitleMoTaVaAssignee()
    {
        var request = new CreateTicketRequest("  Tieu de  ", "  Mo ta  ", null, null, "  Lam  ");
        var ok = TicketRequestValidator.TryValidateCreate(request, out var values, out _);
        Assert.True(ok);
        Assert.Equal("Tieu de", values.Title);
        Assert.Equal("Mo ta", values.Description);
        Assert.Equal("Lam", values.Assignee);
    }

    // ---- TryValidateFilter ----

    [Fact]
    public void Filter_StatusSai_TuChoi()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            "khong_hop_le", null, null, null, null, null, null, null,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'status'", error);
    }

    [Fact]
    public void Filter_SeverityCategorySai_TuChoi()
    {
        var okSeverity = TicketRequestValidator.TryValidateFilter(
            null, "sieu_cao", null, null, null, null, null, null,
            out _, out _, out _, out var errorSeverity);
        Assert.False(okSeverity);
        Assert.Contains("'severity'", errorSeverity);

        var okCategory = TicketRequestValidator.TryValidateFilter(
            null, null, "khong_ro", null, null, null, null, null,
            out _, out _, out _, out var errorCategory);
        Assert.False(okCategory);
        Assert.Contains("'category'", errorCategory);
    }

    [Fact]
    public void Filter_StatusSeverityCategoryHopLe_ParseDung()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            "in_progress", "critical", "database", null, null, null, null, null,
            out var filter, out _, out _, out _);
        Assert.True(ok);
        Assert.Equal(TicketStatus.InProgress, filter.Status);
        Assert.Equal(TicketSeverity.Critical, filter.Severity);
        Assert.Equal(TicketCategory.Database, filter.Category);
    }

    [Fact]
    public void Filter_UnassignedTrue_CungLucVoiAssignee_TuChoi()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, "Lam", "true", null, null, null,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("unassigned", error);
    }

    [Fact]
    public void Filter_UnassignedTrue_KhongCoAssignee_HopLe()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, "true", null, null, null,
            out var filter, out _, out _, out _);
        Assert.True(ok);
        Assert.True(filter.Unassigned);
    }

    [Fact]
    public void Filter_QQuaDai_TuChoi()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, new string('a', TicketRequestValidator.QMax + 1), null, null,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'q'", error);
    }

    [Fact]
    public void Filter_QChuaKyTuDacBiet_DuocEscapeDungThuTu()
    {
        // '\' phải escape TRƯỚC % và _, không thì '\' mới sinh ra từ bước sau bị
        // escape lại lần nữa.
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, @"50%_off\done", null, null,
            out var filter, out _, out _, out _);
        Assert.True(ok);
        Assert.Equal(@"50\%\_off\\done", filter.Q);
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("0")]
    [InlineData("-1")]
    public void Filter_LimitSaiKieuHoacKhongDuong_TuChoi(string limit)
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, null, limit, null,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'limit'", error);
    }

    [Fact]
    public void Filter_LimitVuotQua100_TuChoi()
    {
        // Xem comment trong TicketRequestValidator: spec khong ro "kep" hay "tu
        // choi" khi limit > 100 — chon tu choi, test nay khoa lai quyet dinh do.
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, null, "101", null,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'limit'", error);
    }

    [Fact]
    public void Filter_KhongGuiLimit_MacDinh20()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, null, null, null,
            out _, out var limitValue, out _, out _);
        Assert.True(ok);
        Assert.Equal(20, limitValue);
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("-1")]
    public void Filter_OffsetAmHoacSaiKieu_TuChoi(string offset)
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, null, null, offset,
            out _, out _, out _, out var error);
        Assert.False(ok);
        Assert.Contains("'offset'", error);
    }

    [Fact]
    public void Filter_KhongGuiOffset_MacDinh0()
    {
        var ok = TicketRequestValidator.TryValidateFilter(
            null, null, null, null, null, null, null, null,
            out _, out _, out var offsetValue, out _);
        Assert.True(ok);
        Assert.Equal(0, offsetValue);
    }
}

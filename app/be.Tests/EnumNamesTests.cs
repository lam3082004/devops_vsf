using OpsBoard.Models;
using Xunit;

namespace OpsBoard.Tests;

/// EnumNames là cầu nối giữa enum C# và "tên dây" snake_case dùng trong JSON,
/// query string và cột ENUM của MySQL. Lệch một chỗ là lệch cả ba.
public class EnumNamesTests
{
    [Theory]
    [InlineData(TicketStatus.Open, "open")]
    [InlineData(TicketStatus.InProgress, "in_progress")]
    [InlineData(TicketStatus.Resolved, "resolved")]
    [InlineData(TicketStatus.Closed, "closed")]
    public void ToWire_RaSnakeCase(TicketStatus value, string mongDoi) =>
        Assert.Equal(mongDoi, EnumNames<TicketStatus>.ToWire(value));

    [Theory]
    [InlineData(ActivityAction.StatusChanged, "status_changed")]
    [InlineData(ActivityAction.DescriptionChanged, "description_changed")]
    public void ToWire_ApDungChoMoiEnum(ActivityAction value, string mongDoi) =>
        Assert.Equal(mongDoi, EnumNames<ActivityAction>.ToWire(value));

    [Fact]
    public void TryParse_NhanDungTenDay()
    {
        Assert.True(EnumNames<TicketStatus>.TryParse("in_progress", out var status));
        Assert.Equal(TicketStatus.InProgress, status);
    }

    [Fact]
    public void TryParse_BoQuaKhoangTrangThua()
    {
        Assert.True(EnumNames<TicketSeverity>.TryParse("  critical  ", out var severity));
        Assert.Equal(TicketSeverity.Critical, severity);
    }

    [Theory]
    [InlineData("IN_PROGRESS")]
    [InlineData("InProgress")]
    [InlineData("in progress")]
    [InlineData("2")]
    [InlineData("")]
    [InlineData(null)]
    public void TryParse_TuChoiDangKhac(string? raw)
    {
        // Hợp đồng chỉ có MỘT dạng. Nhận thêm dạng khác thì client sẽ gửi lung tung
        // rồi phụ thuộc vào đó, và query string sẽ lệch với JSON.
        Assert.False(EnumNames<TicketStatus>.TryParse(raw, out _));
    }

    [Fact]
    public void WireValues_LietKeDuGiaTri() =>
        Assert.Equal("open|in_progress|resolved|closed", EnumNames<TicketStatus>.WireValues);
}

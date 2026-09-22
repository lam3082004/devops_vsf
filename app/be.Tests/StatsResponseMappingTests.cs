using OpsBoard.Contracts;
using OpsBoard.Models;
using Xunit;

namespace OpsBoard.Tests;

/// StatsResponse.BuildByStatus/BuildBySeverity la noi duy nhat hien thuc hoa
/// bay #1 cua /stats (api-spec.md): map dictionary counts tho sang du 4 key,
/// ke ca khi count=0 — khoa lai truc tiep bang test thuan, khong can DB.
public class StatsResponseMappingTests
{
    [Fact]
    public void BuildByStatus_DictionaryThieuKey_FieldThieu_LaKhong()
    {
        var counts = new Dictionary<TicketStatus, int> { [TicketStatus.Open] = 4 };

        var result = StatsResponse.BuildByStatus(counts);

        Assert.Equal(4, result.Open);
        Assert.Equal(0, result.InProgress);
        Assert.Equal(0, result.Resolved);
        Assert.Equal(0, result.Closed);
    }

    [Fact]
    public void BuildByStatus_DictionaryRong_TatCaBangKhong()
    {
        var result = StatsResponse.BuildByStatus(new Dictionary<TicketStatus, int>());

        Assert.Equal(0, result.Open);
        Assert.Equal(0, result.InProgress);
        Assert.Equal(0, result.Resolved);
        Assert.Equal(0, result.Closed);
    }

    [Fact]
    public void BuildByStatus_DictionaryDuBonKey_MapDungTungField()
    {
        var counts = new Dictionary<TicketStatus, int>
        {
            [TicketStatus.Open] = 4,
            [TicketStatus.InProgress] = 2,
            [TicketStatus.Resolved] = 1,
            [TicketStatus.Closed] = 50,
        };

        var result = StatsResponse.BuildByStatus(counts);

        Assert.Equal(4, result.Open);
        Assert.Equal(2, result.InProgress);
        Assert.Equal(1, result.Resolved);
        Assert.Equal(50, result.Closed);
    }

    [Fact]
    public void BuildBySeverity_DictionaryThieuKey_FieldThieu_LaKhong()
    {
        var counts = new Dictionary<TicketSeverity, int> { [TicketSeverity.Critical] = 3 };

        var result = StatsResponse.BuildBySeverity(counts);

        Assert.Equal(0, result.Low);
        Assert.Equal(0, result.Medium);
        Assert.Equal(0, result.High);
        Assert.Equal(3, result.Critical);
    }

    [Fact]
    public void BuildBySeverity_DictionaryRong_TatCaBangKhong()
    {
        var result = StatsResponse.BuildBySeverity(new Dictionary<TicketSeverity, int>());

        Assert.Equal(0, result.Low);
        Assert.Equal(0, result.Medium);
        Assert.Equal(0, result.High);
        Assert.Equal(0, result.Critical);
    }

    [Fact]
    public void BuildBySeverity_DictionaryDuBonKey_MapDungTungField()
    {
        var counts = new Dictionary<TicketSeverity, int>
        {
            [TicketSeverity.Low] = 20,
            [TicketSeverity.Medium] = 25,
            [TicketSeverity.High] = 9,
            [TicketSeverity.Critical] = 3,
        };

        var result = StatsResponse.BuildBySeverity(counts);

        Assert.Equal(20, result.Low);
        Assert.Equal(25, result.Medium);
        Assert.Equal(9, result.High);
        Assert.Equal(3, result.Critical);
    }
}

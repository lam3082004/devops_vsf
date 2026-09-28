using OpsBoard.Common;
using OpsBoard.Infrastructure;
using OpsBoard.Services;
using Xunit;

namespace OpsBoard.Tests;

/// /load giới hạn số lần đốt CPU đồng thời (LOAD_MAX_CONCURRENT) — review ngoài 26/09.
public class LoadLimitTests
{
    private static Config ConfigWithLimit(int limit) => new(
        Port: 0, DbHost: "127.0.0.1", DbPort: 3306, DbName: "test", DbUser: "test",
        DbPassword: "test", DbTls: false, LoadMaxSeconds: 60, LoadMaxConcurrent: limit);

    [Fact]
    public async Task VuotGioiHan_Tra429NgayKhongDotCpu_XongThiNhaCho()
    {
        var config = ConfigWithLimit(1);
        var limiter = new LoadLimiter(config);
        var service = new LoadService(config, limiter);

        var first = service.RunAsync("1");
        var started = DateTime.UtcNow;
        var second = await service.RunAsync("1");
        Assert.False(second.IsSuccess);
        Assert.Equal(ErrorKind.TooManyRequests, second.Kind);
        Assert.True(DateTime.UtcNow - started < TimeSpan.FromMilliseconds(500), "429 phai tra ngay, khong xep hang");

        Assert.True((await first).IsSuccess);

        // Request đầu xong thì chỗ được trả lại.
        Assert.True(limiter.TryEnter());
        limiter.Release();
    }

    [Fact]
    public async Task ThamSoSai_Tra400_KhongChiemCho()
    {
        var config = ConfigWithLimit(1);
        var limiter = new LoadLimiter(config);
        var result = await new LoadService(config, limiter).RunAsync("0");

        Assert.Equal(ErrorKind.Validation, result.Kind);
        Assert.True(limiter.TryEnter());
    }
}

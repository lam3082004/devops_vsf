using System.Diagnostics;
using OpsBoard.Common;
using OpsBoard.Contracts;
using OpsBoard.Infrastructure;

namespace OpsBoard.Services;

public sealed class LoadService : ILoadService
{
    private readonly Config _config;
    private readonly LoadLimiter _limiter;

    public LoadService(Config config, LoadLimiter limiter)
    {
        _config = config;
        _limiter = limiter;
    }

    public async Task<Result<LoadResponse>> RunAsync(string? secondsRaw)
    {
        var max = _config.LoadMaxSeconds;

        if (secondsRaw is null)
        {
            return Result<LoadResponse>.Fail("thieu tham so 'seconds'");
        }

        if (!long.TryParse(secondsRaw.Trim(), out var seconds))
        {
            return Result<LoadResponse>.Fail("'seconds' phai la so nguyen duong");
        }

        if (seconds < 1 || seconds > max)
        {
            return Result<LoadResponse>.Fail("'seconds' ngoai khoang cho phep");
        }

        // Task.Run đẩy vòng lặp bận ra thread pool: nếu chặn thẳng trong một
        // request handler async, nó sẽ chiếm cả worker của Kestrel, /health
        // không phản hồi và App Service coi instance là hỏng — mất cả M2 lẫn M7.
        //
        // Giới hạn số lần đốt ĐỒNG THỜI: mỗi request giữ bận một thread tới LoadMaxSeconds,
        // không giới hạn thì vài chục request song song trên 1 vCPU làm đói thread pool →
        // /health chậm theo → health check của App Service thay instance (review ngoài
        // 26/09). Vượt giới hạn trả 429 ngay, không xếp hàng, không đốt CPU.
        if (!_limiter.TryEnter())
        {
            return Result<LoadResponse>.TooManyRequests(
                $"dang co {_config.LoadMaxConcurrent} request /load chay, thu lai sau");
        }

        try
        {
            var iterations = await Task.Run(() => Burn(seconds));
            return Result<LoadResponse>.Ok(new LoadResponse(seconds, iterations));
        }
        finally
        {
            _limiter.Release();
        }
    }

    private static ulong Burn(long seconds)
    {
        var stopwatch = Stopwatch.StartNew();
        var budget = TimeSpan.FromSeconds(seconds);
        ulong iterations = 0;
        while (stopwatch.Elapsed < budget)
        {
            iterations++;
        }

        return iterations;
    }
}

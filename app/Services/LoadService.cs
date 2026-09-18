using System.Diagnostics;
using NodeRegistry.Common;
using NodeRegistry.Contracts;
using NodeRegistry.Infrastructure;

namespace NodeRegistry.Services;

public sealed class LoadService : ILoadService
{
    private readonly Config _config;

    public LoadService(Config config) => _config = config;

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
        var iterations = await Task.Run(() => Burn(seconds));
        return Result<LoadResponse>.Ok(new LoadResponse(seconds, iterations));
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

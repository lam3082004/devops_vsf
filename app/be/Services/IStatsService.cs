using OpsBoard.Contracts;

namespace OpsBoard.Services;

public interface IStatsService
{
    Task<StatsResponse> GetAsync(CancellationToken ct);
}

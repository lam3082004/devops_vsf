using OpsBoard.Contracts;
using OpsBoard.Repositories;

namespace OpsBoard.Services;

/// /stats không có lỗi nghiệp vụ nào (không validate input, không 400/404) —
/// trả thẳng Task<StatsResponse>, giống IHealthService.CheckAsync() trả
/// thẳng Task<bool> không bọc Result.
public sealed class StatsService : IStatsService
{
    private readonly ITicketRepository _repository;

    public StatsService(ITicketRepository repository) => _repository = repository;

    public async Task<StatsResponse> GetAsync(CancellationToken ct)
    {
        var raw = await _repository.GetStatsAsync(ct);
        return new StatsResponse(
            raw.Total,
            StatsResponse.BuildByStatus(raw.ByStatus),
            StatsResponse.BuildBySeverity(raw.BySeverity),
            raw.OpenCritical,
            raw.AvgResolutionMinutes);
    }
}

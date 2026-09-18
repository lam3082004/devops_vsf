using NodeRegistry.Infrastructure;
using NodeRegistry.Repositories;

namespace NodeRegistry.Services;

public sealed class HealthService : IHealthService
{
    /// Thời gian tối đa cho một lần ping. Ngắn, vì health check của App
    /// Service có timeout riêng và không được để nó treo.
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(1);

    private readonly IDatabaseRepository _databaseRepository;
    private readonly IAppLogger _logger;

    public HealthService(IDatabaseRepository databaseRepository, IAppLogger logger)
    {
        _databaseRepository = databaseRepository;
        _logger = logger;
    }

    public async Task<bool> CheckAsync()
    {
        using var cts = new CancellationTokenSource(Timeout);
        try
        {
            await _databaseRepository.PingAsync(cts.Token);
            return true;
        }
        catch (Exception ex)
        {
            _logger.Warn("khong ping duoc DB", ("event", "health_degraded"), ("error", ex.Message));
            return false;
        }
    }
}

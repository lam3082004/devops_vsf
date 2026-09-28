using OpsBoard.Infrastructure;
using OpsBoard.Repositories;

namespace OpsBoard.Services;

public sealed class HealthService : IHealthService
{
    /// Thời gian tối đa cho một lần ping. Ngắn, vì health check của App
    /// Service có timeout riêng và không được để nó treo.
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(1);

    private readonly IDatabaseRepository _databaseRepository;
    private readonly SchemaInitializer _schema;
    private readonly IAppLogger _logger;

    public HealthService(IDatabaseRepository databaseRepository, SchemaInitializer schema, IAppLogger logger)
    {
        _databaseRepository = databaseRepository;
        _schema = schema;
        _logger = logger;
    }

    public async Task<bool> CheckAsync()
    {
        using var cts = new CancellationTokenSource(Timeout);
        try
        {
            await _databaseRepository.PingAsync(cts.Token);
        }
        catch (Exception ex)
        {
            _logger.Warn("khong ping duoc DB", ("event", "health_degraded"), ("error", ex.Message));
            return false;
        }

        // Ping được chưa đủ: bảng chưa có thì /items sẽ 503 — chưa sẵn sàng nhận traffic.
        // TryEnsureAsync tự log lỗi và không ném ra ngoài.
        return await _schema.TryEnsureAsync(_databaseRepository, cts.Token);
    }
}

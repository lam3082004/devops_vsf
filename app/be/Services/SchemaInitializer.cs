using OpsBoard.Infrastructure;
using OpsBoard.Repositories;

namespace OpsBoard.Services;

/// Nhớ (trong process) schema đã tạo xong chưa, và thử tạo lại nếu chưa.
///
/// Vì sao cần: lần tạo bảng lúc khởi động có thể thất bại (DB chưa lên, firewall MySQL
/// chưa kịp có rule của outbound IP — `make up` 3 pha). Trước đây app không bao giờ thử
/// lại, trong khi /health chỉ ping DB: DB lên là /health 200, warm-up của swap cho qua,
/// nhưng /items 503 vì bảng không có (review ngoài 26/09, `known-issues.md` #24).
/// Nay /health gọi TryEnsureAsync sau khi ping được: readiness = DB ping được VÀ schema xong.
///
/// Singleton: cờ phải sống qua các request. Sau khi đã xong thì không chạy DDL nữa —
/// CREATE TABLE IF NOT EXISTS vẫn idempotent nếu process khởi động lại.
public sealed class SchemaInitializer
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly IAppLogger _logger;
    private volatile bool _ready;

    public SchemaInitializer(IAppLogger logger) => _logger = logger;

    public bool IsReady => _ready;

    /// true nếu schema đã sẵn sàng (trước đó hoặc vừa tạo xong). Có lần thử khác đang
    /// chạy thì trả false ngay thay vì xếp hàng — health check không được treo.
    public async Task<bool> TryEnsureAsync(IDatabaseRepository repository, CancellationToken cancellationToken)
    {
        if (_ready)
        {
            return true;
        }

        if (!await _gate.WaitAsync(0, cancellationToken))
        {
            return false;
        }

        try
        {
            if (_ready)
            {
                return true;
            }

            await repository.EnsureSchemaAsync(cancellationToken);
            _ready = true;
            _logger.Info("schema san sang", ("event", "schema_ready"));
            return true;
        }
        catch (Exception ex)
        {
            _logger.Warn(
                "chua tao duoc bang, /health se thu lai o lan goi sau",
                ("event", "schema_failed"), ("error", ex.Message));
            return false;
        }
        finally
        {
            _gate.Release();
        }
    }
}

namespace OpsBoard.Repositories;

/// Thao tác hạ tầng cấp DB (không phải riêng bảng `nodes`) — tạo schema lúc
/// khởi động, ping cho health check.
public interface IDatabaseRepository
{
    Task EnsureSchemaAsync(CancellationToken cancellationToken = default);

    Task PingAsync(CancellationToken cancellationToken);
}

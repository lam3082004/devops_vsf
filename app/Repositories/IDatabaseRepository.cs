namespace NodeRegistry.Repositories;

/// Thao tác hạ tầng cấp DB (không phải riêng bảng `nodes`) — tạo schema lúc
/// khởi động, ping cho health check.
public interface IDatabaseRepository
{
    Task EnsureSchemaAsync();

    Task PingAsync(CancellationToken cancellationToken);
}

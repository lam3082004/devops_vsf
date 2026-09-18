using MySqlConnector;

namespace NodeRegistry.Repositories;

public sealed class DatabaseRepository : IDatabaseRepository
{
    private readonly MySqlDataSource _dataSource;

    public DatabaseRepository(MySqlDataSource dataSource) => _dataSource = dataSource;

    /// Tạo bảng nếu chưa có. Chạy được nhiều lần (idempotent) nên khởi động
    /// lại app bao nhiêu lần cũng không lỗi.
    public async Task EnsureSchemaAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            CREATE TABLE IF NOT EXISTS nodes (
                id            BIGINT       NOT NULL AUTO_INCREMENT,
                name          VARCHAR(200) NOT NULL,
                address       VARCHAR(100) NULL,
                role          VARCHAR(50)  NOT NULL DEFAULT 'worker',
                last_seen_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uk_nodes_name (name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """;
        await command.ExecuteNonQueryAsync();
    }

    /// Không tự áp timeout ở đây — đó là quyết định của HealthService (chính
    /// sách "chờ bao lâu thì coi là chết" thuộc về nghiệp vụ, không phải
    /// truy cập dữ liệu).
    public async Task PingAsync(CancellationToken cancellationToken)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT 1";
        await command.ExecuteScalarAsync(cancellationToken);
    }
}

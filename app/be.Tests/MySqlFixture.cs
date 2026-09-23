using MySqlConnector;
using OpsBoard.Infrastructure;
using OpsBoard.Repositories;
using Xunit;

namespace OpsBoard.Tests;

/// Khai báo collection "mysql" dùng chung một MySqlFixture cho mọi test class
/// chạm DB thật (`TicketsApiTests`, `TicketRepositoryTests`). BẮT BUỘC gắn
/// `[Collection("mysql")]` lên các class đó — xUnit chạy song song THEO
/// COLLECTION, hai class cùng `DELETE FROM tickets` song song sẽ phá nhau
/// (be.md BE-5). Test thuần không gắn collection này vẫn chạy song song bình
/// thường.
[CollectionDefinition("mysql")]
public sealed class MySqlCollection : ICollectionFixture<MySqlFixture>
{
}

/// Dựng schema MỘT LẦN cho cả collection thay vì mỗi test class tự
/// EnsureSchemaAsync. Đọc biến môi trường `TEST_DB_*` — KHÔNG dùng thẳng
/// `DB_HOST`/`DB_PASSWORD`... của app để tránh ai lỡ nạp `.env.local` khiến
/// test chạm nhầm DB dev.
public sealed class MySqlFixture : IAsyncLifetime
{
    /// Null khi thiếu TEST_DB_HOST — mọi test trong collection lúc đó đều bị
    /// RequiresMySqlFactAttribute skip nên không ai đọc property này, nhưng
    /// vẫn khai nullable cho rõ ràng thay vì null! che giấu.
    public MySqlDataSource? DataSource { get; private set; }

    /// PHẢI no-op (không throw) khi thiếu TEST_DB_HOST: không chắc chắn 100%
    /// xUnit bỏ qua việc construct fixture khi mọi test trong collection đều
    /// bị Skip, nên fixture phải an toàn ở cả hai trường hợp (be.md BE-5).
    public async Task InitializeAsync()
    {
        var host = Environment.GetEnvironmentVariable("TEST_DB_HOST");
        if (string.IsNullOrWhiteSpace(host))
        {
            return;
        }

        var port = int.TryParse(Environment.GetEnvironmentVariable("TEST_DB_PORT"), out var parsedPort)
            ? parsedPort
            : 3306;

        var config = new Config(
            Port: 0,
            DbHost: host,
            DbPort: port,
            DbName: Environment.GetEnvironmentVariable("TEST_DB_NAME") ?? string.Empty,
            DbUser: Environment.GetEnvironmentVariable("TEST_DB_USER") ?? string.Empty,
            DbPassword: Environment.GetEnvironmentVariable("TEST_DB_PASSWORD") ?? string.Empty,
            // Container dev (d4-mysql, cổng 3307) và service container CI đều
            // không bật TLS.
            DbTls: false,
            LoadMaxSeconds: 60);

        DataSource = MySqlDataSourceFactory.Create(config);
        await new DatabaseRepository(DataSource).EnsureSchemaAsync();
    }

    public Task DisposeAsync()
    {
        DataSource?.Dispose();
        return Task.CompletedTask;
    }
}

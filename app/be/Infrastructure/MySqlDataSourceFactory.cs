using MySqlConnector;

namespace OpsBoard.Infrastructure;

public static class MySqlDataSourceFactory
{
    /// Tạo data source ở chế độ lazy: app KHỞI ĐỘNG ĐƯỢC NGAY CẢ KHI DB CHƯA
    /// SẴN SÀNG — /health sẽ trả 503 cho tới khi kết nối được. MySqlDataSource
    /// không mở kết nối lúc tạo, chỉ khi có OpenConnectionAsync() đầu tiên.
    public static MySqlDataSource Create(Config config)
    {
        var connectionString = new MySqlConnectionStringBuilder
        {
            Server = config.DbHost,
            Port = (uint)config.DbPort,
            UserID = config.DbUser,
            Password = config.DbPassword,
            Database = config.DbName,
            SslMode = config.DbTls ? MySqlSslMode.Required : MySqlSslMode.Disabled,
            MaximumPoolSize = 5,
            ConnectionTimeout = 5,
        }.ConnectionString;

        return new MySqlDataSourceBuilder(connectionString).Build();
    }
}

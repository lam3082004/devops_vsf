using MySqlConnector;
using NodeRegistry.Models;

namespace NodeRegistry.Repositories;

public sealed class NodeRepository : INodeRepository
{
    /// Số bản ghi tối đa trả về, để một node lỡ spam không kéo cả bảng ra.
    private const int ListLimit = 100;

    private readonly MySqlDataSource _dataSource;

    public NodeRepository(MySqlDataSource dataSource) => _dataSource = dataSource;

    /// Trùng `name` thì cập nhật lần thấy cuối thay vì báo lỗi — đúng ngữ
    /// nghĩa của một registry: node tự khai báo lại mỗi lần khởi động.
    public async Task<Node> RegisterAsync(string name, string? address, string role)
    {
        await using (var connection = await _dataSource.OpenConnectionAsync())
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                INSERT INTO nodes (name, address, role)
                VALUES (@name, @address, @role)
                ON DUPLICATE KEY UPDATE
                    address = VALUES(address),
                    role = VALUES(role),
                    last_seen_at = CURRENT_TIMESTAMP
                """;
            command.Parameters.AddWithValue("@name", name);
            command.Parameters.AddWithValue("@address", (object?)address ?? DBNull.Value);
            command.Parameters.AddWithValue("@role", role);
            await command.ExecuteNonQueryAsync();
        }

        return await GetByNameAsync(name);
    }

    public async Task<Node> GetByNameAsync(string name)
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        command.CommandText =
            "SELECT id, name, address, role, last_seen_at FROM nodes WHERE name = @name LIMIT 1";
        command.Parameters.AddWithValue("@name", name);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            throw new InvalidOperationException("node khong ton tai sau khi ghi");
        }

        return ReadNode(reader);
    }

    public async Task<List<Node>> ListAsync()
    {
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, address, role, last_seen_at FROM nodes
            ORDER BY last_seen_at DESC, id DESC LIMIT @limit
            """;
        command.Parameters.AddWithValue("@limit", ListLimit);

        await using var reader = await command.ExecuteReaderAsync();
        var results = new List<Node>();
        while (await reader.ReadAsync())
        {
            results.Add(ReadNode(reader));
        }

        return results;
    }

    private static Node ReadNode(MySqlDataReader reader)
    {
        var addressOrdinal = reader.GetOrdinal("address");
        return new Node(
            Id: reader.GetInt64("id"),
            Name: reader.GetString("name"),
            Address: reader.IsDBNull(addressOrdinal) ? null : reader.GetString("address"),
            Role: reader.GetString("role"),
            LastSeenAt: DateTime.SpecifyKind(reader.GetDateTime("last_seen_at"), DateTimeKind.Utc));
    }
}

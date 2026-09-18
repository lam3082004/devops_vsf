using NodeRegistry.Models;

namespace NodeRegistry.Repositories;

/// Truy cập dữ liệu THUẦN TUÝ — không validate, không quyết định response.
/// Ném exception nguyên bản của MySqlConnector khi DB lỗi; ai gọi tự quyết
/// định biến nó thành gì (xem DatabaseExceptionFilter).
public interface INodeRepository
{
    Task<Node> RegisterAsync(string name, string? address, string role);

    Task<Node> GetByNameAsync(string name);

    Task<List<Node>> ListAsync();
}

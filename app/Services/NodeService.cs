using NodeRegistry.Common;
using NodeRegistry.Models;
using NodeRegistry.Repositories;
using NodeRegistry.Validation;

namespace NodeRegistry.Services;

/// Nghiệp vụ cho "node": validate đầu vào rồi mới gọi repository. Lỗi DB
/// (exception từ MySqlConnector) KHÔNG bắt ở đây — để nó nổi lên tới
/// DatabaseExceptionFilter, tránh lặp lại cùng một khối try/catch ở từng
/// service/controller.
public sealed class NodeService : INodeService
{
    private readonly INodeRepository _repository;

    public NodeService(INodeRepository repository) => _repository = repository;

    public async Task<IReadOnlyList<Node>> ListAsync() => await _repository.ListAsync();

    public async Task<Result<Node>> RegisterAsync(RegisterNodeRequest request)
    {
        if (!NodeRequestValidator.TryValidate(request, out var values, out var error))
        {
            return Result<Node>.Fail(error.Reason());
        }

        var node = await _repository.RegisterAsync(values.Name, values.Address, values.Role);
        return Result<Node>.Ok(node);
    }
}

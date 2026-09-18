using NodeRegistry.Common;
using NodeRegistry.Models;

namespace NodeRegistry.Services;

public interface INodeService
{
    Task<IReadOnlyList<Node>> ListAsync();

    Task<Result<Node>> RegisterAsync(RegisterNodeRequest request);
}

using NodeRegistry.Common;
using NodeRegistry.Contracts;

namespace NodeRegistry.Services;

public interface ILoadService
{
    Task<Result<LoadResponse>> RunAsync(string? secondsRaw);
}

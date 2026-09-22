using OpsBoard.Common;
using OpsBoard.Contracts;

namespace OpsBoard.Services;

public interface ILoadService
{
    Task<Result<LoadResponse>> RunAsync(string? secondsRaw);
}

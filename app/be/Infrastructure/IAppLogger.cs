namespace OpsBoard.Infrastructure;

/// Interface hoá logging để middleware/filter/service inject qua DI thay vì
/// gọi thẳng một class static — dễ thay implementation (test double) hơn.
public interface IAppLogger
{
    void Info(string message, params (string Key, object? Value)[] fields);

    void Warn(string message, params (string Key, object? Value)[] fields);

    void Error(string message, params (string Key, object? Value)[] fields);
}

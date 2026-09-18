namespace NodeRegistry.Services;

public interface IHealthService
{
    /// true = ping DB thành công trong thời gian cho phép.
    Task<bool> CheckAsync();
}

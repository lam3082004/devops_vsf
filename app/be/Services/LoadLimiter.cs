using OpsBoard.Infrastructure;

namespace OpsBoard.Services;

/// Đếm số request /load đang đốt CPU trong process (singleton). Giới hạn theo instance:
/// autoscale lên 2 instance thì tổng tối đa gấp đôi — đúng ý, mỗi máy tự bảo vệ mình.
public sealed class LoadLimiter
{
    private readonly SemaphoreSlim _slots;

    public LoadLimiter(Config config) => _slots = new SemaphoreSlim(config.LoadMaxConcurrent, config.LoadMaxConcurrent);

    /// Không chờ: hết chỗ thì trả false ngay.
    public bool TryEnter() => _slots.Wait(0);

    public void Release() => _slots.Release();
}

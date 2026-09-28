namespace OpsBoard.Common;

/// Exception cố ý của /boom (topic.md mục 2: "ném exception"). Kiểu riêng để
/// BoomExceptionFilter nhận ra nó và giữ đúng hợp đồng 500 `boom`, thay vì rơi vào
/// DatabaseExceptionFilter (bắt mọi exception khác → 503 database_unavailable).
public sealed class BoomException : Exception
{
    public BoomException(string message) : base(message)
    {
    }
}

using OpsBoard.Models;

namespace OpsBoard.Contracts;

/// BẪY: KHÔNG dùng Dictionary<TicketStatus,int> — enum làm key không đi qua
/// JsonStringEnumConverter cùng quy tắc như value (sẽ ra tên C# PascalCase
/// thay vì snake_case), và Dictionary thiếu key khi count=0 trong khi spec
/// đòi đủ 4 key. Record tường minh, PropertyNamingPolicy tự cho ra in_progress.
public sealed record StatsByStatus(int Open, int InProgress, int Resolved, int Closed);

public sealed record StatsBySeverity(int Low, int Medium, int High, int Critical);

public sealed record StatsResponse(
    int Total,
    StatsByStatus ByStatus,
    StatsBySeverity BySeverity,
    int OpenCritical,
    long? AvgResolutionMinutes)
{
    /// Tách khỏi service để test được không cần DB — chỗ duy nhất hiện thực
    /// hoá bẫy "đủ 4 key kể cả count=0".
    public static StatsByStatus BuildByStatus(IReadOnlyDictionary<TicketStatus, int> counts) => new(
        Open: counts.GetValueOrDefault(TicketStatus.Open),
        InProgress: counts.GetValueOrDefault(TicketStatus.InProgress),
        Resolved: counts.GetValueOrDefault(TicketStatus.Resolved),
        Closed: counts.GetValueOrDefault(TicketStatus.Closed));

    public static StatsBySeverity BuildBySeverity(IReadOnlyDictionary<TicketSeverity, int> counts) => new(
        Low: counts.GetValueOrDefault(TicketSeverity.Low),
        Medium: counts.GetValueOrDefault(TicketSeverity.Medium),
        High: counts.GetValueOrDefault(TicketSeverity.High),
        Critical: counts.GetValueOrDefault(TicketSeverity.Critical));
}

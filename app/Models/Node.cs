namespace NodeRegistry.Models;

/// Entity — đúng một dòng của bảng `nodes`.
public sealed record Node(long Id, string Name, string? Address, string Role, DateTime LastSeenAt);

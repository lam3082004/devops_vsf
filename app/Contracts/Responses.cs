namespace NodeRegistry.Contracts;

/// DTO trả ra ngoài — tách khỏi Models (entity/domain) để đổi hợp đồng API
/// không kéo theo đổi entity và ngược lại. Property null bị bỏ qua khi
/// serialize (xem Program.cs: DefaultIgnoreCondition.WhenWritingNull) nên
/// dùng chung một ErrorResponse cho mọi loại lỗi vẫn ra đúng field như cũ:
/// bad_request có "reason", boom có "detail", còn lại chỉ có "error".
public sealed record ErrorResponse(string Error, string? Reason = null, string? Detail = null);

public sealed record HealthResponse(string Status, string Db);

public sealed record VersionResponse(string Sha);

public sealed record LoadResponse(long BurnedSeconds, ulong Iterations);

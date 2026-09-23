using System.Text.Json.Serialization;

namespace OpsBoard.Contracts;

/// DTO trả ra ngoài — tách khỏi Models (entity/domain) để đổi hợp đồng API
/// không kéo theo đổi entity và ngược lại.
///
/// Quy tắc null (docs/docs_app/api-spec.md, mục Quy ước chung): DTO dữ liệu
/// (Ticket, Comment, Activity, Stats) LUÔN trả đủ field kể cả null, để frontend
/// gõ kiểu được. Chỉ ErrorResponse bỏ field null. Vì ErrorResponse là kiểu duy
/// nhất cần hành vi đó, ApiSetup đặt mặc định toàn cục là Never và chính nó mang
/// attribute ngược lại — hai attribute ở một chỗ, thay vì rải attribute lên mọi
/// DTO dữ liệu và phải nhớ gắn mỗi lần thêm DTO mới.
///
/// Record positional BẮT BUỘC dùng [property: ...]; gắn thẳng lên tham số thì
/// attribute không đi vào property và quy tắc trên âm thầm mất tác dụng.
public sealed record ErrorResponse(
    string Error,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Reason = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Detail = null);

public sealed record HealthResponse(string Status, string Db);

public sealed record VersionResponse(string Sha);

public sealed record LoadResponse(long BurnedSeconds, ulong Iterations);

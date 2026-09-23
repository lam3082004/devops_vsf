using System.Text.Json;

namespace OpsBoard.Models;

/// Một nguồn sự thật duy nhất cho "tên dây" của enum: chuỗi snake_case dùng trong
/// JSON, trong query string, trong cột ENUM của MySQL và trong from_value/to_value
/// của bảng activities.
///
/// Vì sao cần lớp này khi đã có JsonStringEnumConverter: converter chỉ áp cho
/// System.Text.Json (body + response). Query string đi qua model binding của MVC
/// (Enum.Parse ignoreCase) nên "in_progress" KHÔNG khớp InProgress — bind lỗi thì
/// [ApiController] trả ProblemDetails, phá hợp đồng ErrorResponse. Vì vậy controller
/// nhận string? rồi parse ở đây, giống cách /load?seconds= đang làm.
///
/// Dùng ĐÚNG quy tắc đặt tên của JsonNamingPolicy.SnakeCaseLower để hai đường
/// (JSON và query string) không bao giờ lệch nhau.
public static class EnumNames<TEnum>
    where TEnum : struct, Enum
{
    private static readonly Dictionary<string, TEnum> ByWire =
        Enum.GetValues<TEnum>().ToDictionary(ToWire, value => value, StringComparer.Ordinal);

    /// InProgress → "in_progress"
    public static string ToWire(TEnum value) =>
        JsonNamingPolicy.SnakeCaseLower.ConvertName(value.ToString());

    /// Khớp CHÍNH XÁC chữ thường có gạch dưới: "IN_PROGRESS" hay "InProgress" đều bị
    /// từ chối. Hợp đồng chỉ có một dạng; nhận nhiều dạng thì client sẽ gửi lung tung
    /// rồi phụ thuộc vào đó.
    public static bool TryParse(string? raw, out TEnum value) =>
        ByWire.TryGetValue(raw?.Trim() ?? string.Empty, out value);

    /// Danh sách giá trị hợp lệ, dùng trong message lỗi 400.
    public static string WireValues => string.Join("|", ByWire.Keys);
}

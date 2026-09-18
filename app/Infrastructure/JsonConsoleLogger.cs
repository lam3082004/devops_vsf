using System.Text.Json.Nodes;

namespace NodeRegistry.Infrastructure;

/// Mỗi lời gọi in ĐÚNG MỘT dòng JSON ra stdout — time, level, các field tuỳ
/// event, message — không có scope/target lồng nhau. Đăng ký làm singleton
/// (cùng một instance dùng từ lúc app chưa có DI container tới lúc chạy),
/// thay hẳn framework logging mặc định của ASP.NET Core (nó ghi multi-line,
/// không phải 1 record/dòng như yêu cầu).
public sealed class JsonConsoleLogger : IAppLogger
{
    public void Info(string message, params (string Key, object? Value)[] fields) =>
        Write("info", message, fields);

    public void Warn(string message, params (string Key, object? Value)[] fields) =>
        Write("warn", message, fields);

    public void Error(string message, params (string Key, object? Value)[] fields) =>
        Write("error", message, fields);

    private static void Write(string level, string message, (string Key, object? Value)[] fields)
    {
        var line = new JsonObject
        {
            ["time"] = DateTimeOffset.UtcNow.ToString("O"),
            ["level"] = level,
        };

        foreach (var (key, value) in fields)
        {
            line[key] = ToJsonValue(value);
        }

        line["message"] = message;

        Console.Out.WriteLine(line.ToJsonString());
    }

    private static JsonNode? ToJsonValue(object? value) => value switch
    {
        null => null,
        string s => JsonValue.Create(s),
        bool b => JsonValue.Create(b),
        int i => JsonValue.Create(i),
        long l => JsonValue.Create(l),
        ulong ul => JsonValue.Create(ul),
        double d => JsonValue.Create(d),
        _ => JsonValue.Create(value.ToString()),
    };
}

using System.Globalization;

namespace OpsBoard.Infrastructure;

/// Lỗi cấu hình. Message chỉ chứa TÊN BIẾN, không bao giờ chứa giá trị —
/// để không lỡ log mật khẩu khi báo lỗi.
public sealed class ConfigException : Exception
{
    private ConfigException(string message) : base(message)
    {
    }

    public static ConfigException Missing(string var) =>
        new($"bien moi truong bat buoc '{var}' bi thieu hoac rong");

    public static ConfigException Invalid(string var, string reason) =>
        new($"bien moi truong '{var}' khong hop le: {reason}");

    public static ConfigException UnresolvedKeyVault(string var) =>
        new($"bien moi truong '{var}' van la tham chieu Key Vault chua resolve " +
            "(@Microsoft.KeyVault...): kiem tra quyen cua managed identity tren Key Vault");
}

/// Đăng ký làm singleton trong DI (`builder.Services.AddSingleton(config)`) —
/// service/repository nào cần cấu hình thì constructor-inject thẳng, không
/// đọc biến môi trường rải rác ở nhiều lớp.
public sealed record Config(
    int Port,
    string DbHost,
    int DbPort,
    string DbName,
    string DbUser,
    string DbPassword,
    bool DbTls,
    long LoadMaxSeconds,
    // Số request /load chạy đồng thời tối đa trên MỘT instance (LoadLimiter). Mặc định 4:
    // D19 dùng 3 luồng và đã đẩy CPU 1 vCPU lên ~100%.
    int LoadMaxConcurrent = 4,
    // Tuỳ chọn: vắng → không bật telemetry (test, CI, chạy local). Xem Infrastructure/Telemetry.cs.
    string? AppInsightsConnectionString = null)
{
    /// Tiền tố mà App Service để nguyên trong biến môi trường khi nó KHÔNG
    /// resolve được tham chiếu Key Vault (mất quyền, sai URI, secret bị xoá...).
    private const string KeyVaultPrefix = "@Microsoft.KeyVault(";

    public static Config FromEnvironment()
    {
        var dbPassword = Required("DB_PASSWORD");
        if (IsUnresolvedKeyVault(dbPassword))
        {
            throw ConfigException.UnresolvedKeyVault("DB_PASSWORD");
        }

        var loadMaxSeconds = NumberInt64("LOAD_MAX_SECONDS", 60);
        if (loadMaxSeconds is < 1 or > 300)
        {
            throw ConfigException.Invalid("LOAD_MAX_SECONDS", "phai nam trong khoang 1..=300");
        }

        var loadMaxConcurrent = NumberInt64("LOAD_MAX_CONCURRENT", 4);
        if (loadMaxConcurrent is < 1 or > 16)
        {
            throw ConfigException.Invalid("LOAD_MAX_CONCURRENT", "phai nam trong khoang 1..=16");
        }

        return new Config(
            Port: PortNumber("PORT", 8080),
            DbHost: Required("DB_HOST"),
            DbPort: PortNumber("DB_PORT", 3306),
            DbName: Required("DB_NAME"),
            DbUser: Required("DB_USER"),
            DbPassword: dbPassword,
            DbTls: Boolean("DB_TLS", true),
            LoadMaxSeconds: loadMaxSeconds,
            LoadMaxConcurrent: (int)loadMaxConcurrent,
            AppInsightsConnectionString: Optional("APPLICATIONINSIGHTS_CONNECTION_STRING"));
    }

    /// Tiền tố tham chiếu Key Vault chưa resolve — Telemetry dùng để phân biệt
    /// "không cấu hình" với "cấu hình nhưng App Service không đọc được secret".
    public static bool IsUnresolvedKeyVault(string value) =>
        value.StartsWith(KeyVaultPrefix, StringComparison.Ordinal);

    private static string? Optional(string var)
    {
        var value = Environment.GetEnvironmentVariable(var);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static string Required(string var)
    {
        var value = Environment.GetEnvironmentVariable(var);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw ConfigException.Missing(var);
        }

        return value;
    }

    // Review 30/09 #14: bản cũ `(int)NumberInt64(...)` tràn số lặng lẽ, rồi `(uint)` ở
    // MySqlDataSourceFactory biến số âm thành port khổng lồ. Kiểm khoảng như LOAD_MAX_*.
    private static int PortNumber(string var, int fallback)
    {
        var value = NumberInt64(var, fallback);
        if (value < 1 || value > 65535)
        {
            throw ConfigException.Invalid(var, "phai nam trong khoang 1..=65535");
        }

        return (int)value;
    }

    private static long NumberInt64(string var, long fallback)
    {
        var raw = Environment.GetEnvironmentVariable(var);
        if (string.IsNullOrWhiteSpace(raw))
        {
            return fallback;
        }

        if (!long.TryParse(raw.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var value))
        {
            throw ConfigException.Invalid(var, "khong phai so hop le");
        }

        return value;
    }

    private static bool Boolean(string var, bool fallback)
    {
        var raw = Environment.GetEnvironmentVariable(var);
        if (string.IsNullOrWhiteSpace(raw))
        {
            return fallback;
        }

        return raw.Trim().ToLowerInvariant() switch
        {
            "true" or "1" or "yes" => true,
            "false" or "0" or "no" => false,
            _ => throw ConfigException.Invalid(var, "chi nhan true/false"),
        };
    }
}

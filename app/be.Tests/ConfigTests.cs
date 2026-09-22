using OpsBoard.Infrastructure;
using Xunit;

namespace OpsBoard.Tests;

public class ConfigTests
{
    [Fact]
    public void KeyVaultPrefixBiTuChoi()
    {
        var ex = ConfigException.UnresolvedKeyVault("DB_PASSWORD");
        Assert.Contains("DB_PASSWORD", ex.Message);
        Assert.StartsWith("@Microsoft.KeyVault(", "@Microsoft.KeyVault(SecretUri=https://x)");
    }

    [Fact]
    public void ThongBaoLoiKhongBaoGioChuaGiaTri()
    {
        var ex = ConfigException.Invalid("DB_PORT", "khong phai so hop le");
        Assert.Contains("DB_PORT", ex.Message);
        Assert.DoesNotContain("3306", ex.Message);
    }
}

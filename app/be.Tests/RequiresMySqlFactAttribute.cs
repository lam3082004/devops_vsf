using Xunit;

namespace OpsBoard.Tests;

/// `[Fact]` con: tự đặt `Skip` ngay trong constructor, nên xUnit báo test này
/// là *skipped* (không phải fail) ngay ở giai đoạn discovery khi không có
/// MySQL thật ở môi trường chạy test — xUnit 2.9.2 chưa có `Assert.Skip`
/// (be.md BE-5). Dùng tiền tố `TEST_DB_*` (không phải `DB_HOST` trần) để ai
/// lỡ nạp `.env.local` (biến `DB_*` của app) vào shell không vô tình khiến
/// test chạy nhắm vào DB dev.
public sealed class RequiresMySqlFactAttribute : FactAttribute
{
    public RequiresMySqlFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TEST_DB_HOST")))
        {
            Skip = "khong co MySQL: dat TEST_DB_HOST de chay";
        }
    }
}

/// Bản `[Theory]`, cùng cơ chế skip như RequiresMySqlFactAttribute — `Theory`
/// và `Fact` là hai lớp cơ sở khác nhau trong xUnit nên phải khai riêng.
public sealed class RequiresMySqlTheoryAttribute : TheoryAttribute
{
    public RequiresMySqlTheoryAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TEST_DB_HOST")))
        {
            Skip = "khong co MySQL: dat TEST_DB_HOST de chay";
        }
    }
}

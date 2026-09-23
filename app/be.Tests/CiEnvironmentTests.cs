using Xunit;

namespace OpsBoard.Tests;

/// Chặn "skip im lặng": rủi ro lớn nhất của cơ chế RequiresMySqlFactAttribute
/// là gõ sai tên biến trong ci.yml khiến TOÀN BỘ test chạm DB bị skip mà CI
/// vẫn xanh. Test THUẦN này (không cần DB, không nằm trong collection "mysql")
/// chỉ thật sự kiểm tra khi chạy trong CI (GitHub Actions luôn tự đặt
/// `CI=true`) — chạy ở máy dev không có TEST_DB_HOST vẫn phải xanh bình
/// thường (be.md BE-5).
public class CiEnvironmentTests
{
    [Fact]
    public void TrongCI_PhaiCoBienMoiTruongMySql()
    {
        if (Environment.GetEnvironmentVariable("CI") != "true")
        {
            return;
        }

        Assert.False(string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TEST_DB_HOST")));
    }
}

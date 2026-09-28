using OpsBoard.Infrastructure;
using OpsBoard.Repositories;
using OpsBoard.Services;
using Xunit;

namespace OpsBoard.Tests;

/// Readiness = ping được DB **và** schema đã tạo (review ngoài 26/09, known-issues #24).
/// Trước đây lần tạo bảng lúc khởi động thất bại thì không bao giờ thử lại, còn /health
/// chỉ ping → 200 trong khi /items 503.
public class SchemaReadinessTests
{
    private sealed class FakeDatabase : IDatabaseRepository
    {
        public bool PingFails { get; set; }

        public int EnsureFailuresLeft { get; set; }

        public int EnsureCalls { get; private set; }

        public Task EnsureSchemaAsync(CancellationToken cancellationToken = default)
        {
            EnsureCalls++;
            if (EnsureFailuresLeft > 0)
            {
                EnsureFailuresLeft--;
                throw new InvalidOperationException("Table 'appdb.tickets' doesn't exist");
            }

            return Task.CompletedTask;
        }

        public Task PingAsync(CancellationToken cancellationToken) =>
            PingFails ? throw new InvalidOperationException("Couldn't connect to server") : Task.CompletedTask;
    }

    [Fact]
    public async Task TaoBangThatBai_ThiChuaSanSang_ToiKhiTaoLaiDuoc()
    {
        var db = new FakeDatabase { EnsureFailuresLeft = 1 };
        var schema = new SchemaInitializer(new JsonConsoleLogger());
        var health = new HealthService(db, schema, new JsonConsoleLogger());

        // Lúc khởi động: DB chưa cho tạo bảng.
        Assert.False(await schema.TryEnsureAsync(db, CancellationToken.None));

        // DB đã ping được nhưng lần tạo trước hỏng — vẫn phải 503 cho tới khi tạo xong.
        db.EnsureFailuresLeft = 1;
        Assert.False(await health.CheckAsync());

        Assert.True(await health.CheckAsync());
        Assert.True(schema.IsReady);

        // Đã xong thì không chạy DDL thêm lần nào nữa.
        var callsWhenReady = db.EnsureCalls;
        Assert.True(await health.CheckAsync());
        Assert.Equal(callsWhenReady, db.EnsureCalls);
    }

    [Fact]
    public async Task KhongPingDuocDb_ThiKhongThuTaoBang()
    {
        var db = new FakeDatabase { PingFails = true };
        var health = new HealthService(db, new SchemaInitializer(new JsonConsoleLogger()), new JsonConsoleLogger());

        Assert.False(await health.CheckAsync());
        Assert.Equal(0, db.EnsureCalls);
    }
}

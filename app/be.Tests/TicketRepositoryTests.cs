using OpsBoard.Models;
using OpsBoard.Repositories;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// Test tích hợp gọi THẲNG TicketRepository (không qua HTTP) trỏ MySQL thật
/// (TEST_DB_*) — khoá đúng thứ mock không bao giờ bắt được: quên
/// `cmd.Transaction = tx` cho một command trong khối transaction. `[Collection("mysql")]`
/// BẮT BUỘC — xem TicketsApiTests.cs.
[Collection("mysql")]
public sealed class TicketRepositoryTests : IAsyncLifetime
{
    private readonly MySqlFixture _fixture;
    private TicketRepository? _repository;

    public TicketRepositoryTests(MySqlFixture fixture) => _fixture = fixture;

    public async Task InitializeAsync()
    {
        if (_fixture.DataSource is null)
        {
            // Không có MySQL thật: [RequiresMySqlFact] trong class này đã skip.
            return;
        }

        _repository = new TicketRepository(_fixture.DataSource);
        await CleanTicketsAsync();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    /// Test đáng tiền nhất của BE-5 (be.md): UpdateAsync với expectedStatus
    /// LỆCH với trạng thái thật trong DB mô phỏng TOCTOU (người khác đã đổi
    /// status giữa lúc service đọc và lúc ghi). Repository phải trả null VÀ
    /// KHÔNG được để activity lọt qua — nếu một command nào đó trong khối
    /// transaction quên gán `cmd.Transaction = tx`, INSERT activity sẽ tự
    /// commit độc lập dù UPDATE chính đã rollback; mock không bao giờ chạm
    /// được loại lỗi này vì nó không mô phỏng transaction thật.
    [RequiresMySqlFact]
    public async Task StatusLech_Rollback_KhongThemActivity()
    {
        var ticket = await _repository!.CreateAsync(
            "Ticket cho test rollback", description: null,
            TicketSeverity.Medium, TicketCategory.Other,
            reporter: "tester", assignee: null, CancellationToken.None);

        // CreateAsync đã ghi 1 activity 'created' — đây là baseline.
        var activitiesBefore = await CountActivitiesAsync(ticket.Id);
        Assert.Equal(1, activitiesBefore);

        var update = new TicketUpdate(
            Title: "Ten moi neu UPDATE thanh cong",
            DescriptionChanged: false, Description: null,
            Severity: null,
            Category: null,
            AssigneeChanged: false, Assignee: null,
            Status: null,
            ResolvedAtChanged: false, ResolvedAt: null);

        var activities = new List<ActivityWrite> { new(ActivityAction.TitleChanged, null, null) };

        // Ticket vừa tạo đang 'open' thật, nhưng ta truyền expectedStatus =
        // 'resolved' — WHERE ... AND status = @expected không khớp dòng nào.
        var result = await _repository.UpdateAsync(
            ticket.Id, update, activities,
            expectedStatus: TicketStatus.Resolved, actor: "tester", CancellationToken.None);

        Assert.Null(result);

        var activitiesAfter = await CountActivitiesAsync(ticket.Id);
        Assert.Equal(activitiesBefore, activitiesAfter);

        // Title cũng phải giữ nguyên — UPDATE không được commit một phần nào.
        var reloaded = await _repository.GetByIdAsync(ticket.Id, CancellationToken.None);
        Assert.Equal("Ticket cho test rollback", reloaded!.Title);
    }

    private async Task<int> CountActivitiesAsync(long ticketId)
    {
        await using var connection = await _fixture.DataSource!.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM activities WHERE ticket_id = @ticketId";
        command.Parameters.AddWithValue("@ticketId", ticketId);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private async Task CleanTicketsAsync()
    {
        await using var connection = await _fixture.DataSource!.OpenConnectionAsync();
        await using var command = connection.CreateCommand();
        // ON DELETE CASCADE dọn theo comments + activities (DatabaseRepository).
        command.CommandText = "DELETE FROM tickets";
        await command.ExecuteNonQueryAsync();
    }
}

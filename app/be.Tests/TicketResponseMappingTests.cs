using OpsBoard.Contracts;
using OpsBoard.Models;
using Xunit;

namespace OpsBoard.Tests;

/// TicketResponse.FromEntity la noi duy nhat anh xa entity Ticket sang DTO tra
/// ra ngoai (app/be/CLAUDE.md: Controllers khong duoc tra entity thang ra
/// HTTP). Test o day khoa lai: khong lam roi/null nham field khi map, va giu
/// dung gia tri null cua entity (assignee, description, resolved_at) thay vi
/// tu doi thanh gia tri mac dinh khac.
public class TicketResponseMappingTests
{
    [Fact]
    public void FromEntity_AnhXaDuTatCaField()
    {
        var createdAt = new DateTime(2026, 9, 21, 13, 50, 0, DateTimeKind.Utc);
        var updatedAt = new DateTime(2026, 9, 21, 14, 0, 0, DateTimeKind.Utc);
        var resolvedAt = new DateTime(2026, 9, 21, 15, 0, 0, DateTimeKind.Utc);
        var ticket = new Ticket(
            Id: 41,
            Title: "MySQL het ket noi",
            Description: "Mo ta chi tiet",
            Severity: TicketSeverity.Critical,
            Category: TicketCategory.Database,
            Status: TicketStatus.Resolved,
            Reporter: "Nam",
            Assignee: "Lam",
            CreatedAt: createdAt,
            UpdatedAt: updatedAt,
            ResolvedAt: resolvedAt);

        var response = TicketResponse.FromEntity(ticket);

        Assert.Equal(41, response.Id);
        Assert.Equal("MySQL het ket noi", response.Title);
        Assert.Equal("Mo ta chi tiet", response.Description);
        Assert.Equal(TicketSeverity.Critical, response.Severity);
        Assert.Equal(TicketCategory.Database, response.Category);
        Assert.Equal(TicketStatus.Resolved, response.Status);
        Assert.Equal("Nam", response.Reporter);
        Assert.Equal("Lam", response.Assignee);
        Assert.Equal(createdAt, response.CreatedAt);
        Assert.Equal(updatedAt, response.UpdatedAt);
        Assert.Equal(resolvedAt, response.ResolvedAt);
    }

    [Fact]
    public void FromEntity_GiuNguyenFieldNull_KhongTuDoiThanhGiaTriKhac()
    {
        // description/assignee/resolved_at null o entity (ticket vua tao,
        // chua ai nhan, chua giai quyet) thi DTO phai van null — khong duoc
        // map nham thanh chuoi rong hay gia tri mac dinh nao khac, vi
        // api-spec.md yeu cau DTO du lieu LUON giu field null de frontend go
        // kieu dung.
        var ticket = new Ticket(
            Id: 1,
            Title: "Ticket toi thieu",
            Description: null,
            Severity: TicketSeverity.Medium,
            Category: TicketCategory.Other,
            Status: TicketStatus.Open,
            Reporter: "Lam",
            Assignee: null,
            CreatedAt: DateTime.UtcNow,
            UpdatedAt: DateTime.UtcNow,
            ResolvedAt: null);

        var response = TicketResponse.FromEntity(ticket);

        Assert.Null(response.Description);
        Assert.Null(response.Assignee);
        Assert.Null(response.ResolvedAt);
    }
}

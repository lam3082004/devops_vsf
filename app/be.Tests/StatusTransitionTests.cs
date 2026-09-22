using OpsBoard.Models;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// State machine chuyen trang thai ticket (prd.md muc 2). Ham thuan, khong
/// cham DB. Du 16 o (4x4) doi chieu dung bang PRD, kem ca 4 o "cung trang
/// thai hien tai" (from == to) — PHAI la false theo be.md BE-3.
public class StatusTransitionTests
{
    [Theory]
    // Tu open
    [InlineData(TicketStatus.Open, TicketStatus.Open, false)]
    [InlineData(TicketStatus.Open, TicketStatus.InProgress, true)]
    [InlineData(TicketStatus.Open, TicketStatus.Resolved, false)]
    [InlineData(TicketStatus.Open, TicketStatus.Closed, false)]
    // Tu in_progress
    [InlineData(TicketStatus.InProgress, TicketStatus.Open, true)]
    [InlineData(TicketStatus.InProgress, TicketStatus.InProgress, false)]
    [InlineData(TicketStatus.InProgress, TicketStatus.Resolved, true)]
    [InlineData(TicketStatus.InProgress, TicketStatus.Closed, false)]
    // Tu resolved
    [InlineData(TicketStatus.Resolved, TicketStatus.Open, false)]
    [InlineData(TicketStatus.Resolved, TicketStatus.InProgress, true)]
    [InlineData(TicketStatus.Resolved, TicketStatus.Resolved, false)]
    [InlineData(TicketStatus.Resolved, TicketStatus.Closed, true)]
    // Tu closed — ngo cut, ke ca closed->closed
    [InlineData(TicketStatus.Closed, TicketStatus.Open, false)]
    [InlineData(TicketStatus.Closed, TicketStatus.InProgress, false)]
    [InlineData(TicketStatus.Closed, TicketStatus.Resolved, false)]
    [InlineData(TicketStatus.Closed, TicketStatus.Closed, false)]
    public void ChuyenTrangThai_DoiChieuDungBangPrd(TicketStatus from, TicketStatus to, bool expected)
    {
        Assert.Equal(expected, TicketStatusTransition.IsValid(from, to));
    }
}

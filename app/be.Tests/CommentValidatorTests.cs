using OpsBoard.Models;
using OpsBoard.Validation;
using Xunit;

namespace OpsBoard.Tests;

/// TryValidateComment (POST /items/{id}/comments, be.md BE-4) là hàm thuần,
/// không chạm DB — test được không cần dựng DI/DB, giống TicketValidatorTests.
public class CommentValidatorTests
{
    [Fact]
    public void BodyRongSauTrim_BiTuChoi()
    {
        var ok = TicketRequestValidator.TryValidateComment(
            new CreateCommentRequest("   "), out _, out var error);

        Assert.False(ok);
        Assert.Equal("'body' khong duoc rong", error);
    }

    [Fact]
    public void BodyChuoiRong_BiTuChoi()
    {
        var ok = TicketRequestValidator.TryValidateComment(
            new CreateCommentRequest(""), out _, out var error);

        Assert.False(ok);
        Assert.Equal("'body' khong duoc rong", error);
    }

    [Fact]
    public void BodyDungBienToiDa_HopLe()
    {
        var body = new string('a', TicketRequestValidator.BodyMax);

        var ok = TicketRequestValidator.TryValidateComment(
            new CreateCommentRequest(body), out var value, out var error);

        Assert.True(ok);
        Assert.Null(error);
        Assert.Equal(body, value);
    }

    [Fact]
    public void BodyVuotBienToiDaMotKyTu_BiTuChoi()
    {
        var body = new string('a', TicketRequestValidator.BodyMax + 1);

        var ok = TicketRequestValidator.TryValidateComment(
            new CreateCommentRequest(body), out _, out var error);

        Assert.False(ok);
        Assert.Contains("'body'", error);
    }

    [Fact]
    public void BodyCoKhoangTrangDauCuoi_DuocTrim()
    {
        var ok = TicketRequestValidator.TryValidateComment(
            new CreateCommentRequest("  Dang xem connection pool  "), out var value, out var error);

        Assert.True(ok);
        Assert.Equal("Dang xem connection pool", value);
    }
}

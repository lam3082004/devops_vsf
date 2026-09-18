using NodeRegistry.Models;
using NodeRegistry.Validation;
using Xunit;

namespace NodeRegistry.Tests;

public class NodesTests
{
    [Fact]
    public void NameRongBiTuChoi()
    {
        var ok = NodeRequestValidator.TryValidate(
            new RegisterNodeRequest("   ", null, null), out _, out var error);
        Assert.False(ok);
        Assert.Equal(ValidationError.NameEmpty, error);
    }

    [Fact]
    public void NameQuaDaiBiTuChoi()
    {
        var request = new RegisterNodeRequest(new string('a', NodeRequestValidator.NameMax + 1), null, null);
        var ok = NodeRequestValidator.TryValidate(request, out _, out var error);
        Assert.False(ok);
        Assert.Equal(ValidationError.NameTooLong, error);
    }

    [Fact]
    public void RoleMacDinhLaWorker()
    {
        var ok = NodeRequestValidator.TryValidate(
            new RegisterNodeRequest(" node-01 ", null, null), out var values, out _);
        Assert.True(ok);
        Assert.Equal("node-01", values.Name);
        Assert.Null(values.Address);
        Assert.Equal("worker", values.Role);
    }
}

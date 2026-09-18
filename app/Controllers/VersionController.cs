using Microsoft.AspNetCore.Mvc;
using NodeRegistry.Contracts;

namespace NodeRegistry.Controllers;

[ApiController]
public sealed class VersionController : ControllerBase
{
    private readonly AppMetadata _metadata;

    public VersionController(AppMetadata metadata) => _metadata = metadata;

    [HttpGet("/version")]
    public IActionResult Get() => Ok(new VersionResponse(_metadata.GitSha));
}

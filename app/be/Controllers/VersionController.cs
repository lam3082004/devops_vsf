using Microsoft.AspNetCore.Mvc;
using OpsBoard.Contracts;

namespace OpsBoard.Controllers;

[ApiController]
public sealed class VersionController : ControllerBase
{
    private readonly AppMetadata _metadata;

    public VersionController(AppMetadata metadata) => _metadata = metadata;

    [HttpGet("/version")]
    // Không đụng DB, không nhánh lỗi nào — chỉ một schema thành công.
    [ProducesResponseType(typeof(VersionResponse), StatusCodes.Status200OK)]
    public IActionResult Get() => Ok(new VersionResponse(_metadata.GitSha));
}

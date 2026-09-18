using Microsoft.AspNetCore.Mvc;
using NodeRegistry.Contracts;
using NodeRegistry.Models;
using NodeRegistry.Services;

namespace NodeRegistry.Controllers;

[ApiController]
public sealed class ItemsController : ControllerBase
{
    private readonly INodeService _nodeService;

    public ItemsController(INodeService nodeService) => _nodeService = nodeService;

    [HttpGet("/items")]
    public async Task<IActionResult> List() => Ok(await _nodeService.ListAsync());

    [HttpPost("/items")]
    public async Task<IActionResult> Register([FromBody] RegisterNodeRequest payload)
    {
        var result = await _nodeService.RegisterAsync(payload);
        if (!result.IsSuccess)
        {
            return BadRequest(new ErrorResponse("bad_request", Reason: result.Error));
        }

        return StatusCode(StatusCodes.Status201Created, result.Value);
    }
}

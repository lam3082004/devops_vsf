namespace NodeRegistry.Models;

/// Payload thô từ client cho POST /items — CHƯA validate, CHƯA trim.
public sealed record RegisterNodeRequest(string Name, string? Address, string? Role);

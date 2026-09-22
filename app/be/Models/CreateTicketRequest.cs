namespace OpsBoard.Models;

/// Payload thô từ client cho POST /items — CHƯA validate, CHƯA trim.
///
/// `Title` cố tình khai KHÔNG nullable và KHÔNG có default (giống RegisterNodeRequest.Name
/// trước đây): thiếu 'title' trong JSON body thì System.Text.Json tự báo lỗi
/// required-property-missing, ModelState lỗi với key "Title" →
/// ApiSetup.ConfigureApiBehavior tự chuyển thành 400 bad_request với
/// reason "'title' khong hop le". Đây là cơ chế binding có sẵn — validator
/// KHÔNG tự viết lại kiểm tra "thiếu title".
///
/// Severity/Category khai kiểu enum NULLABLE (không phải string): body JSON đi qua
/// JsonStringEnumConverter (ApiSetup.ConfigureJson) nên bind trực tiếp được, khác
/// với query string phải nhận string? rồi tự parse (xem EnumNames.cs).
public sealed record CreateTicketRequest(
    string Title,
    string? Description,
    TicketSeverity? Severity,
    TicketCategory? Category,
    string? Assignee);

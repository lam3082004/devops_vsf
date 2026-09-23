namespace OpsBoard.Models;

/// Payload thô từ client cho POST /items/{id}/comments — CHƯA validate, CHƯA trim.
///
/// `Body` cố tình khai KHÔNG nullable và KHÔNG có default (giống
/// CreateTicketRequest.Title): thiếu 'body' trong JSON body thì
/// System.Text.Json tự báo lỗi required-property-missing → 400 bad_request
/// qua ApiSetup.ConfigureApiBehavior — validator KHÔNG tự viết lại kiểm tra
/// "thiếu".
public sealed record CreateCommentRequest(string Body);

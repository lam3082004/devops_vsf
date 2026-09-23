using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using OpsBoard.Contracts;

namespace OpsBoard.Filters;

/// Đọc header X-User-Name cho MỌI thao tác ghi (POST/PATCH) và chặn sớm nếu thiếu.
///
/// App không có đăng nhập: danh tính là cái tên người dùng tự nhập ở giao diện, còn
/// biên tin cậy là IP whitelist của App Service (docs/docs_app/brief.md, R5 đã được
/// chấp nhận). Tên này đi vào reporter/assignee/author/actor nên phải có mặt và
/// được chuẩn hoá ở MỘT chỗ, không để mỗi controller tự đọc header.
public sealed class UserNameFilter : IActionFilter
{
    public const string HeaderName = "X-User-Name";
    public const string ItemKey = "user_name";
    public const int MaxLength = 50;

    public void OnActionExecuting(ActionExecutingContext context)
    {
        var method = context.HttpContext.Request.Method;
        if (!HttpMethods.IsPost(method) && !HttpMethods.IsPatch(method))
        {
            return;
        }

        var raw = context.HttpContext.Request.Headers[HeaderName].ToString().Trim();

        if (raw.Length == 0)
        {
            context.Result = BadRequest($"thieu header '{HeaderName}'");
            return;
        }

        // HTTP header không mang được ký tự ngoài ASCII đáng tin cậy (trình duyệt tự mã hoá theo
        // ISO-8859-1 hoặc ném lỗi trước cả khi gửi), nên frontend percent-encode UTF-8 trước khi đặt
        // header — decode lại ở đây. Uri.UnescapeDataString bọc try/catch phòng trường hợp chuỗi có `%`
        // lẻ không hợp lệ mà một số phiên bản coi là lỗi định dạng: dùng lại `raw` thô thay vì trả 500.
        string value;
        try
        {
            value = Uri.UnescapeDataString(raw);
        }
        catch (FormatException)
        {
            value = raw;
        }

        if (value.Length > MaxLength)
        {
            context.Result = BadRequest($"'{HeaderName}' toi da {MaxLength} ky tu");
            return;
        }

        context.HttpContext.Items[ItemKey] = value;
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        // Không cần làm gì sau action.
    }

    private static BadRequestObjectResult BadRequest(string reason) =>
        new(new ErrorResponse("bad_request", Reason: reason));

    /// Tên đã được filter kiểm; action nào chạy được tới đây trên POST/PATCH thì
    /// chắc chắn có giá trị. Ném nếu không có là lỗi lập trình (quên đăng ký filter),
    /// không phải lỗi người dùng.
    public static string Require(HttpContext context) =>
        context.Items[ItemKey] as string
        ?? throw new InvalidOperationException($"thieu {ItemKey}: UserNameFilter chua duoc dang ky?");
}

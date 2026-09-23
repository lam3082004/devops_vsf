namespace OpsBoard.Common;

/// Loại lỗi "dự kiến" — quyết định mã HTTP mà controller trả về.
/// Ánh xạ nằm một chỗ duy nhất: ApiControllerBase.Failure.
public enum ErrorKind
{
    /// Input sai → 400 bad_request.
    Validation,

    /// Không tìm thấy tài nguyên → 404 not_found.
    NotFound,

    /// Thao tác hợp lệ về cú pháp nhưng trái luật nghiệp vụ → 409 invalid_transition.
    Conflict,
}

/// Kết quả có thể thất bại "dự kiến" (validate sai, không tìm thấy, xung đột trạng thái),
/// khác với exception dùng cho lỗi HẠ TẦNG bất ngờ (DB chết — xem DatabaseExceptionFilter).
/// Service trả Result thay vì throw cho các lỗi mà controller PHẢI xử lý bằng một
/// response bình thường, không phải một trang lỗi.
public sealed class Result<T>
{
    public bool IsSuccess { get; }

    public T? Value { get; }

    public string? Error { get; }

    /// Chỉ có nghĩa khi IsSuccess = false.
    public ErrorKind Kind { get; }

    private Result(bool isSuccess, T? value, string? error, ErrorKind kind)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
        Kind = kind;
    }

    public static Result<T> Ok(T value) => new(true, value, null, default);

    /// Giữ nguyên nghĩa cũ (400) để mọi chỗ gọi từ trước không phải sửa.
    public static Result<T> Fail(string error) => new(false, default, error, ErrorKind.Validation);

    public static Result<T> NotFound(string error) => new(false, default, error, ErrorKind.NotFound);

    public static Result<T> Conflict(string error) => new(false, default, error, ErrorKind.Conflict);
}

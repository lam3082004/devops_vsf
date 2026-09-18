namespace NodeRegistry.Common;

/// Kết quả có thể thất bại "dự kiến" (validate sai, tham số sai...), khác với
/// exception dùng cho lỗi HẠ TẦNG bất ngờ (DB chết — xem DatabaseExceptionFilter).
/// Service trả Result thay vì throw cho các lỗi mà controller PHẢI xử lý bằng
/// một response bình thường (400), không phải một trang lỗi.
public sealed class Result<T>
{
    public bool IsSuccess { get; }

    public T? Value { get; }

    public string? Error { get; }

    private Result(bool isSuccess, T? value, string? error)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
    }

    public static Result<T> Ok(T value) => new(true, value, null);

    public static Result<T> Fail(string error) => new(false, default, error);
}

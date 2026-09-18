namespace NodeRegistry.Models;

public enum ValidationError
{
    NameEmpty,
    NameTooLong,
    AddressTooLong,
    RoleTooLong,
}

public static class ValidationErrorExtensions
{
    public static string Reason(this ValidationError error) => error switch
    {
        ValidationError.NameEmpty => "'name' khong duoc rong",
        ValidationError.NameTooLong => "'name' toi da 200 ky tu",
        ValidationError.AddressTooLong => "'address' toi da 100 ky tu",
        ValidationError.RoleTooLong => "'role' toi da 50 ky tu",
        _ => "loi khong xac dinh",
    };
}

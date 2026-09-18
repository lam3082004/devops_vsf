using NodeRegistry.Models;

namespace NodeRegistry.Validation;

/// Chuẩn hoá + kiểm tra RegisterNodeRequest trước khi service chạm tới
/// repository. Tách khỏi NodeService để test được logic validate mà không
/// cần dựng DI/DB — thuần hàm, không phụ thuộc gì.
public static class NodeRequestValidator
{
    public const int NameMax = 200;
    public const int RoleMax = 50;
    public const int AddressMax = 100;

    public static bool TryValidate(
        RegisterNodeRequest request,
        out (string Name, string? Address, string Role) values,
        out ValidationError error)
    {
        var name = request.Name.Trim();
        if (name.Length == 0)
        {
            error = ValidationError.NameEmpty;
            values = default;
            return false;
        }

        if (name.Length > NameMax)
        {
            error = ValidationError.NameTooLong;
            values = default;
            return false;
        }

        string? address = null;
        if (!string.IsNullOrWhiteSpace(request.Address))
        {
            address = request.Address.Trim();
            if (address.Length > AddressMax)
            {
                error = ValidationError.AddressTooLong;
                values = default;
                return false;
            }
        }

        var role = string.IsNullOrWhiteSpace(request.Role) ? "worker" : request.Role.Trim();
        if (role.Length > RoleMax)
        {
            error = ValidationError.RoleTooLong;
            values = default;
            return false;
        }

        error = default;
        values = (name, address, role);
        return true;
    }
}

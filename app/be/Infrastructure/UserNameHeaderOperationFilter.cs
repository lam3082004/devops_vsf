using Microsoft.OpenApi;
using OpsBoard.Filters;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace OpsBoard.Infrastructure;

/// UserNameFilter đọc header X-User-Name bằng IActionFilter — vô hình với
/// Swashbuckle vì SwaggerGen dựng schema qua reflection trên tham số action,
/// không thấy filter chạy trước nó. Không có operation filter này thì ai đọc
/// /swagger cũng gửi POST/PATCH thiếu header, ăn 400 mà không hiểu vì sao.
/// Chỉ gắn cho POST/PATCH — GET không cần header nên không được gắn nhầm.
public sealed class UserNameHeaderOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var method = context.ApiDescription.HttpMethod;
        if (!string.Equals(method, "POST", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(method, "PATCH", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        // Swashbuckle 10.2.3 đi theo Microsoft.OpenApi 2.x: namespace đổi thành
        // Microsoft.OpenApi (không còn .Models), OpenApiOperation.Parameters là
        // IList<IOpenApiParameter>, và OpenApiSchema.Type là enum JsonSchemaType
        // thay vì chuỗi "string" như các bản Swashbuckle cũ.
        operation.Parameters ??= new List<IOpenApiParameter>();
        operation.Parameters.Add(new OpenApiParameter
        {
            Name = UserNameFilter.HeaderName,
            In = ParameterLocation.Header,
            Required = true,
            Description = "Tên người thao tác (1-50 ký tự), bắt buộc cho mọi request ghi (POST/PATCH); " +
                "thiếu hoặc rỗng thì UserNameFilter trả 400 trước khi vào action.",
            Schema = new OpenApiSchema { Type = JsonSchemaType.String, MaxLength = UserNameFilter.MaxLength },
        });
    }
}

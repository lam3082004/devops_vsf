namespace OpsBoard.Models;

/// Trạng thái ticket. Luật chuyển trạng thái ở docs/docs_app/prd.md mục 2 (cài đặt từ BE-3).
/// Tên dây (JSON, cột ENUM của MySQL) là snake_case — xem EnumNames.
public enum TicketStatus
{
    Open,
    InProgress,
    Resolved,
    Closed,
}

public enum TicketSeverity
{
    Low,
    Medium,
    High,
    Critical,
}

public enum TicketCategory
{
    Infra,
    App,
    Database,
    Network,
    Security,
    Other,
}

/// Loại thay đổi ghi vào bảng activities. Ghi lịch sử cho MỌI trường đổi,
/// không chỉ status (prd.md mục 2).
public enum ActivityAction
{
    Created,
    StatusChanged,
    AssigneeChanged,
    SeverityChanged,
    CategoryChanged,
    TitleChanged,
    DescriptionChanged,
}

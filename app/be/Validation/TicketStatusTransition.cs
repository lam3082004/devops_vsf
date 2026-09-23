using OpsBoard.Models;

namespace OpsBoard.Validation;

/// State machine chuyển trạng thái ticket (prd.md mục 2) — hàm thuần, KHÔNG
/// phụ thuộc DB, tách hẳn khỏi repository để test được mà không cần dựng DB.
public static class TicketStatusTransition
{
    /// Cùng trạng thái hiện tại (from == to) PHẢI trả false: không nằm trong
    /// bảng "sang được" nào ở dưới, và KHÔNG rơi vào nhánh mặc định nào khác
    /// _ => false (không vô tình cho phép qua).
    public static bool IsValid(TicketStatus from, TicketStatus to) => (from, to) switch
    {
        (TicketStatus.Open, TicketStatus.InProgress) => true,
        (TicketStatus.InProgress, TicketStatus.Open) => true,
        (TicketStatus.InProgress, TicketStatus.Resolved) => true,
        (TicketStatus.Resolved, TicketStatus.InProgress) => true,
        (TicketStatus.Resolved, TicketStatus.Closed) => true,
        // D14 — LỖI CÓ CHỦ Ý: PRD mục 2 nói closed là ngõ cụt. Dòng này cho mở
        // lại ticket đã đóng — một regression THẬT, không phải sửa assert cho sai.
        (TicketStatus.Closed, TicketStatus.Open) => true,
        _ => false,
    };
}

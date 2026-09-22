// Hàm thuần map Activity -> chuỗi tiếng Việt hiển thị trong lịch sử (S5). Tách khỏi component hiển thị
// để dễ test độc lập, cùng kiểu với kanban/age.ts.
import type { Activity, Category, Severity, TicketStatus } from "@/lib/types";
import { CATEGORY_LABELS, SEVERITY_LABELS, STATUS_LABELS } from "@/lib/labels";

// assignee_changed là action duy nhất có thể có from_value/to_value = null theo NGHĨA THẬT (chưa có
// người xử lý) — status/severity/category là enum, không có khái niệm rỗng, nên không cần hàm này.
function displayOrEmpty(value: string | null): string {
  return value ?? "(trống)";
}

// from_value/to_value của Activity chỉ khai `string | null` (log lịch sử chung, backend trả string
// thô — xem lib/types.ts) chứ không phải kiểu enum chặt, nên không thể index thẳng vào STATUS_LABELS/
// SEVERITY_LABELS/CATEGORY_LABELS. Ép kiểu rồi fallback về giá trị gốc nếu không khớp key nào, để
// không vỡ hiển thị nếu backend trả giá trị lạ ngoài enum hiện biết.
function enumLabel<K extends string>(map: Record<K, string>, raw: string | null): string {
  if (raw === null) return "(trống)";
  return (map as Record<string, string>)[raw] ?? raw;
}

export function formatActivityLabel(activity: Activity): string {
  switch (activity.action) {
    case "created":
      return "đã tạo ticket";
    case "status_changed":
      return `${enumLabel<TicketStatus>(STATUS_LABELS, activity.from_value)} → ${enumLabel<TicketStatus>(STATUS_LABELS, activity.to_value)}`;
    case "assignee_changed":
      return `đổi người xử lý: ${displayOrEmpty(activity.from_value)} → ${displayOrEmpty(activity.to_value)}`;
    case "severity_changed":
      return `đổi mức độ: ${enumLabel<Severity>(SEVERITY_LABELS, activity.from_value)} → ${enumLabel<Severity>(SEVERITY_LABELS, activity.to_value)}`;
    case "category_changed":
      return `đổi phân loại: ${enumLabel<Category>(CATEGORY_LABELS, activity.from_value)} → ${enumLabel<Category>(CATEGORY_LABELS, activity.to_value)}`;
    case "title_changed":
      // from_value/to_value luôn null cho action này (VARCHAR(200) không đủ chứa description, và
      // title thì chỉ ghi nhận "đã đổi" — xem api-spec.md mục Activity) — không hiện "null → null".
      return "đã đổi tiêu đề";
    case "description_changed":
      return "đã đổi mô tả";
  }
}

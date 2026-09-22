// Hàm thuần map Activity -> chuỗi tiếng Việt hiển thị trong lịch sử (S5). Tách khỏi component hiển thị
// để dễ test độc lập, cùng kiểu với kanban/age.ts.
import type { Activity } from "@/lib/types";

// assignee_changed là action duy nhất có thể có from_value/to_value = null theo NGHĨA THẬT (chưa có
// người xử lý) — status/severity/category là enum, không có khái niệm rỗng, nên không cần hàm này.
function displayOrEmpty(value: string | null): string {
  return value ?? "(trống)";
}

export function formatActivityLabel(activity: Activity): string {
  switch (activity.action) {
    case "created":
      return "đã tạo ticket";
    case "status_changed":
      return `${activity.from_value} → ${activity.to_value}`;
    case "assignee_changed":
      return `đổi người xử lý: ${displayOrEmpty(activity.from_value)} → ${displayOrEmpty(activity.to_value)}`;
    case "severity_changed":
      return `đổi mức độ: ${activity.from_value} → ${activity.to_value}`;
    case "category_changed":
      return `đổi phân loại: ${activity.from_value} → ${activity.to_value}`;
    case "title_changed":
      // from_value/to_value luôn null cho action này (VARCHAR(200) không đủ chứa description, và
      // title thì chỉ ghi nhận "đã đổi" — xem api-spec.md mục Activity) — không hiện "null → null".
      return "đã đổi tiêu đề";
    case "description_changed":
      return "đã đổi mô tả";
  }
}

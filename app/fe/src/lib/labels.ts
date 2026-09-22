// Bảng ánh xạ giá trị enum (tiếng Anh, khớp api-spec.md) → nhãn hiển thị tiếng Việt. Dùng CHUNG ở mọi
// nơi hiển thị (kanban, danh sách, chi tiết, bộ lọc, thống kê) — không rải chuỗi tiếng Việt rời rạc
// khắp component, để đổi nhãn chỉ cần sửa một chỗ và không lệch nhau giữa các trang.
import type { Category, Severity, TicketStatus } from "@/lib/types";

export const STATUS_LABELS: Record<TicketStatus, string> = {
  open: "Đang mở",
  in_progress: "Đang xử lý",
  resolved: "Đã xử lý",
  closed: "Đã đóng",
};

export const SEVERITY_LABELS: Record<Severity, string> = {
  low: "Thấp",
  medium: "Trung bình",
  high: "Cao",
  critical: "Nghiêm trọng",
};

export const CATEGORY_LABELS: Record<Category, string> = {
  infra: "Hạ tầng",
  app: "Ứng dụng",
  database: "Cơ sở dữ liệu",
  network: "Mạng",
  security: "Bảo mật",
  other: "Khác",
};

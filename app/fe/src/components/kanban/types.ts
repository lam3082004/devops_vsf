// Kiểu dữ liệu riêng cho bảng kanban (FE-2). Tách khỏi lib/types.ts vì đây là hình dạng dữ liệu do
// page.tsx (server) tự gộp lại từ 4 lời gọi GET /items, không phải kiểu response của backend.
import type { Ticket, TicketStatus } from "@/lib/types";

export interface KanbanColumnData {
  items: Ticket[];
  // Lấy từ `total` của response GET /items, KHÔNG phải items.length — items chỉ chứa tối đa
  // `limit` dòng (xem "Cách frontend dựng kanban" ở api-spec.md).
  total: number;
}

export type KanbanColumnsData = Record<TicketStatus, KanbanColumnData>;

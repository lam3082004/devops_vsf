// Kiểu UI riêng cho form sửa ticket (S5) — không phải kiểu response/request của backend (đã có ở
// lib/types.ts). Đây chỉ là hình dạng state cục bộ khi đang sửa (title/description/severity/category/
// assignee), tách ra để các component con (TicketMainPanel, TicketSidePanel) dùng chung.
import type { Category, Severity } from "@/lib/types";

export interface TicketEditDraft {
  title: string;
  description: string;
  severity: Severity;
  category: Category;
  assignee: string;
}

export interface TicketFieldErrors {
  title?: string;
  description?: string;
  assignee?: string;
}

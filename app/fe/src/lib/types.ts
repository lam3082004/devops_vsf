// Kiểu dữ liệu khớp docs/docs_app/api-spec.md. Ticket/Comment/Activity/Stats dùng `| null` thay vì `?`
// vì backend luôn trả đủ field kể cả khi giá trị rỗng (xem "Quy ước chung" trong api-spec.md) — dùng `?`
// sẽ khiến TypeScript không bắt được chỗ quên xử lý null.

export type TicketStatus = "open" | "in_progress" | "resolved" | "closed";
export type Severity = "low" | "medium" | "high" | "critical";
export type Category =
  | "infra"
  | "app"
  | "database"
  | "network"
  | "security"
  | "other";

export interface Ticket {
  id: number;
  title: string;
  description: string | null;
  severity: Severity;
  category: Category;
  status: TicketStatus;
  reporter: string;
  assignee: string | null;
  created_at: string;
  updated_at: string;
  resolved_at: string | null;
}

export interface TicketList {
  items: Ticket[];
  total: number;
  limit: number;
  offset: number;
}

export interface Comment {
  id: number;
  ticket_id: number;
  author: string;
  body: string;
  created_at: string;
}

export interface CommentList {
  comments: Comment[];
}

export type ActivityAction =
  | "created"
  | "status_changed"
  | "assignee_changed"
  | "severity_changed"
  | "category_changed"
  | "title_changed"
  | "description_changed";

export interface Activity {
  id: number;
  ticket_id: number;
  actor: string;
  action: ActivityAction;
  // `title_changed`/`description_changed` luôn để from_value/to_value = null (VARCHAR(200) không đủ
  // chứa description) — xem api-spec.md mục Activity.
  from_value: string | null;
  to_value: string | null;
  created_at: string;
}

export interface TicketDetail {
  ticket: Ticket;
  activities: Activity[];
}

export interface Stats {
  total: number;
  by_status: Record<TicketStatus, number>;
  by_severity: Record<Severity, number>;
  open_critical: number;
  // null khi chưa có ticket nào resolved — không phải 0 (0 nghĩa là "trung bình 0 phút", sai nghĩa).
  avg_resolution_minutes: number | null;
}

// ErrorResponse ngược với Ticket/Comment/...: field null bị bỏ khỏi response nên optional (`?`) ở đây
// là đúng — reason/detail thật sự có thể vắng mặt tuỳ loại lỗi.
export type ApiErrorCode =
  | "bad_request"
  | "not_found"
  | "invalid_transition"
  | "boom"
  | "database_unavailable";

export interface ErrorResponse {
  error: ApiErrorCode;
  reason?: string;
  detail?: string;
}

// --- Request payload (không phải response nên optional field = "không gửi" là đúng ngữ nghĩa) ---

export interface CreateTicketInput {
  title: string;
  description?: string;
  severity?: Severity;
  category?: Category;
  assignee?: string;
}

// PATCH /items/{id}: field vắng mặt = không đổi, field gửi null = xoá giá trị (chỉ áp dụng assignee/
// description). Khai báo assignee/description là `... | null | undefined` (không chỉ optional) để giữ
// được phân biệt này khi JSON.stringify — key omit khi undefined, giữ `"key":null` khi null.
export interface PatchTicketInput {
  title?: string;
  description?: string | null;
  severity?: Severity;
  category?: Category;
  assignee?: string | null;
}

export interface PatchStatusInput {
  status: TicketStatus;
}

export interface AddCommentInput {
  body: string;
}

export interface TicketQuery {
  status?: TicketStatus;
  severity?: Severity;
  category?: Category;
  assignee?: string;
  // Không được dùng cùng lúc với `assignee` (backend trả 400) — xem "Cách frontend dựng kanban".
  unassigned?: boolean;
  q?: string;
  limit?: number;
  offset?: number;
}

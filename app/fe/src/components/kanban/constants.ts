// Hằng số dùng chung cho bảng kanban (FE-2): thứ tự/nhãn cột + bảng chuyển trạng thái hợp lệ.
import type { Severity, TicketStatus } from "@/lib/types";

export const COLUMNS: ReadonlyArray<{ status: TicketStatus; label: string }> = [
  { status: "open", label: "Open" },
  { status: "in_progress", label: "In progress" },
  { status: "resolved", label: "Resolved" },
  { status: "closed", label: "Closed" },
];

// Bảng chuyển trạng thái hợp lệ (PRD mục 2, "Quy tắc nghiệp vụ"):
// open → in_progress; in_progress → open | resolved; resolved → in_progress | closed; closed → (không có).
// Đây chỉ là gợi ý giao diện (làm nổi bật cột được phép thả) — backend vẫn là trọng tài cuối cùng,
// mọi lần thả khác cột đều gọi API và xử lý 409 nếu bị từ chối (xem KanbanBoard.tsx).
export const VALID_TRANSITIONS: Record<TicketStatus, TicketStatus[]> = {
  open: ["in_progress"],
  in_progress: ["open", "resolved"],
  resolved: ["in_progress", "closed"],
  closed: [],
};

// Emoji severity theo wire-frame.md (mục S2).
export const SEVERITY_EMOJI: Record<Severity, string> = {
  critical: "🔴",
  high: "🟠",
  medium: "🟡",
  low: "🟢",
};

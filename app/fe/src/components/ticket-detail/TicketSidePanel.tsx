import { SEVERITY_EMOJI } from "@/components/kanban/constants";
import { CATEGORY_VALUES, SEVERITY_VALUES } from "@/components/tickets/query";
import { formatDateTime } from "@/components/ticket-detail/format";
import { TicketHistoryList } from "@/components/ticket-detail/TicketHistoryList";
import { TicketStatusControl } from "@/components/ticket-detail/TicketStatusControl";
import type { TicketEditDraft, TicketFieldErrors } from "@/components/ticket-detail/types";
import type { Activity, Category, Severity, Ticket } from "@/lib/types";
import { CATEGORY_LABELS, SEVERITY_LABELS } from "@/lib/labels";

const ASSIGNEE_MAX_LENGTH = 50;

interface TicketSidePanelProps {
  ticket: Ticket;
  activities: Activity[];
  isEditing: boolean;
  draft: TicketEditDraft | null;
  fieldErrors: TicketFieldErrors;
  submitting: boolean;
  onDraftChange: (patch: Partial<TicketEditDraft>) => void;
}

// Cột phải (S5): trạng thái + mức độ + phân loại + người xử lý + người báo + ngày tạo + lịch sử.
// Trạng thái luôn tách riêng (TicketStatusControl) — đổi status đi qua endpoint khác (PATCH .../status)
// và áp dụng ngay, không thuộc chế độ "Sửa" của các trường còn lại ở panel này.
export function TicketSidePanel({
  ticket,
  activities,
  isEditing,
  draft,
  fieldErrors,
  submitting,
  onDraftChange,
}: TicketSidePanelProps) {
  return (
    <aside className="flex flex-col gap-4">
      <TicketStatusControl ticket={ticket} />

      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Mức độ</h2>
        {isEditing && draft ? (
          <select
            value={draft.severity}
            onChange={(event) => onDraftChange({ severity: event.target.value as Severity })}
            disabled={submitting}
            className="mt-1 w-full rounded border border-zinc-300 px-3 py-2 text-sm disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
          >
            {SEVERITY_VALUES.map((value) => (
              <option key={value} value={value}>
                {SEVERITY_LABELS[value]}
              </option>
            ))}
          </select>
        ) : (
          <p className="mt-1">
            <span aria-hidden>{SEVERITY_EMOJI[ticket.severity]}</span> {SEVERITY_LABELS[ticket.severity]}
          </p>
        )}
      </div>

      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Phân loại</h2>
        {isEditing && draft ? (
          <select
            value={draft.category}
            onChange={(event) => onDraftChange({ category: event.target.value as Category })}
            disabled={submitting}
            className="mt-1 w-full rounded border border-zinc-300 px-3 py-2 text-sm disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
          >
            {CATEGORY_VALUES.map((value) => (
              <option key={value} value={value}>
                {CATEGORY_LABELS[value]}
              </option>
            ))}
          </select>
        ) : (
          <p className="mt-1">{CATEGORY_LABELS[ticket.category]}</p>
        )}
      </div>

      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Người xử lý</h2>
        {isEditing && draft ? (
          <>
            <input
              value={draft.assignee}
              maxLength={ASSIGNEE_MAX_LENGTH}
              onChange={(event) => onDraftChange({ assignee: event.target.value })}
              placeholder="(trống)"
              disabled={submitting}
              className="mt-1 w-full rounded border border-zinc-300 px-3 py-2 text-sm disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
            />
            {fieldErrors.assignee && (
              <span className="text-sm text-red-600 dark:text-red-400">{fieldErrors.assignee}</span>
            )}
          </>
        ) : (
          <p className="mt-1">{ticket.assignee ?? "—"}</p>
        )}
      </div>

      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Người báo</h2>
        <p className="mt-1">{ticket.reporter}</p>
      </div>

      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Tạo</h2>
        <p className="mt-1">{formatDateTime(ticket.created_at)}</p>
      </div>

      <TicketHistoryList activities={activities} />
    </aside>
  );
}

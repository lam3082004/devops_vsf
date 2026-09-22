import type { TicketEditDraft, TicketFieldErrors } from "@/components/ticket-detail/types";
import type { Ticket } from "@/lib/types";

const TITLE_MAX_LENGTH = 200;
const DESCRIPTION_MAX_LENGTH = 5000;

interface TicketMainPanelProps {
  ticket: Ticket;
  isEditing: boolean;
  draft: TicketEditDraft | null;
  fieldErrors: TicketFieldErrors;
  formError: string | null;
  submitting: boolean;
  onDraftChange: (patch: Partial<TicketEditDraft>) => void;
  onStartEdit: () => void;
  onCancelEdit: () => void;
  onSave: () => void;
}

// Cột trái, phần trên (S5): tiêu đề + [Sửa] + mô tả. Không dùng <form onSubmit> ở đây — "Lưu" phải gộp
// cả severity/category/assignee (TicketSidePanel, cột phải) vào một lần PATCH duy nhất, nên state sửa
// và hàm lưu sống ở component cha chung (TicketDetailView); panel này chỉ hiển thị + gọi callback.
export function TicketMainPanel({
  ticket,
  isEditing,
  draft,
  fieldErrors,
  formError,
  submitting,
  onDraftChange,
  onStartEdit,
  onCancelEdit,
  onSave,
}: TicketMainPanelProps) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm text-zinc-500 dark:text-zinc-400">#{ticket.id}</span>
        {isEditing ? (
          <div className="flex gap-2">
            <button
              type="button"
              onClick={onCancelEdit}
              disabled={submitting}
              className="rounded px-3 py-1.5 text-sm text-zinc-600 hover:bg-zinc-100 disabled:opacity-50 dark:text-zinc-400 dark:hover:bg-zinc-800"
            >
              Huỷ
            </button>
            <button
              type="button"
              onClick={onSave}
              disabled={submitting}
              className="rounded bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-zinc-700 disabled:opacity-50 dark:bg-white dark:text-zinc-900"
            >
              Lưu
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={onStartEdit}
            className="rounded border border-zinc-300 px-3 py-1.5 text-sm hover:bg-zinc-100 dark:border-zinc-700 dark:hover:bg-zinc-800"
          >
            Sửa
          </button>
        )}
      </div>

      {formError && (
        <p
          role="alert"
          className="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-200"
        >
          {formError}
        </p>
      )}

      {isEditing && draft ? (
        <>
          <label className="flex flex-col gap-1 text-sm">
            Tiêu đề*
            <input
              autoFocus
              value={draft.title}
              maxLength={TITLE_MAX_LENGTH}
              onChange={(event) => onDraftChange({ title: event.target.value })}
              disabled={submitting}
              className="rounded border border-zinc-300 px-3 py-2 text-base font-semibold disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
            />
            {fieldErrors.title && (
              <span className="text-red-600 dark:text-red-400">{fieldErrors.title}</span>
            )}
          </label>
          <label className="flex flex-col gap-1 text-sm">
            Mô tả
            <textarea
              value={draft.description}
              maxLength={DESCRIPTION_MAX_LENGTH}
              onChange={(event) => onDraftChange({ description: event.target.value })}
              rows={6}
              disabled={submitting}
              className="rounded border border-zinc-300 px-3 py-2 disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
            />
            {fieldErrors.description && (
              <span className="text-red-600 dark:text-red-400">{fieldErrors.description}</span>
            )}
          </label>
        </>
      ) : (
        <>
          <h1 className="text-xl font-semibold">{ticket.title}</h1>
          <p className="whitespace-pre-wrap text-sm text-zinc-700 dark:text-zinc-300">
            {ticket.description ?? "Chưa có mô tả"}
          </p>
        </>
      )}
    </section>
  );
}

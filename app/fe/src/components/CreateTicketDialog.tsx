"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useUserName } from "@/components/UserNameProvider";
import { useCreateTicketDialog } from "@/components/CreateTicketProvider";
import { CATEGORY_VALUES, SEVERITY_VALUES } from "@/components/tickets/query";
import type { Category, CreateTicketInput, ErrorResponse, Severity } from "@/lib/types";

const TITLE_MAX_LENGTH = 200;
const DESCRIPTION_MAX_LENGTH = 5000;
const ASSIGNEE_MAX_LENGTH = 50;

const DEFAULT_SEVERITY: Severity = "medium";
const DEFAULT_CATEGORY: Category = "other";

interface FieldErrors {
  title?: string;
  description?: string;
  assignee?: string;
}

function initialState() {
  return {
    title: "",
    description: "",
    severity: DEFAULT_SEVERITY as Severity,
    category: DEFAULT_CATEGORY as Category,
    assignee: "",
  };
}

// Hộp thoại tạo ticket (S4). Style mirror NameGate.tsx. "use client" nên KHÔNG import lib/api.ts (file
// đó tự throw khi chạy trong trình duyệt) — gọi qua BFF `/api/tickets` bằng fetch thường.
export function CreateTicketDialog() {
  const router = useRouter();
  const { isOpen, closeDialog } = useCreateTicketDialog();
  const { userName, requireUserName } = useUserName();

  const [form, setForm] = useState(initialState());
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (!isOpen) return null;

  function resetAndClose() {
    setForm(initialState());
    setFieldErrors({});
    setFormError(null);
    closeDialog();
  }

  function validate(): FieldErrors {
    const errors: FieldErrors = {};
    const title = form.title.trim();
    if (title.length < 1 || title.length > TITLE_MAX_LENGTH) {
      errors.title = `Tiêu đề phải 1–${TITLE_MAX_LENGTH} ký tự`;
    }
    if (form.description.length > DESCRIPTION_MAX_LENGTH) {
      errors.description = `Mô tả tối đa ${DESCRIPTION_MAX_LENGTH} ký tự`;
    }
    if (form.assignee.length > ASSIGNEE_MAX_LENGTH) {
      errors.assignee = `Người xử lý tối đa ${ASSIGNEE_MAX_LENGTH} ký tự`;
    }
    return errors;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError(null);

    const errors = validate();
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) return; // lỗi validate → không mất dữ liệu đã nhập (PRD US-02)

    // Tên có thể bị xoá trong lúc hộp đang mở (vd bấm 👤 rồi Huỷ ở NameGate) dù nút mở hộp ở AppHeader
    // đã gate — kiểm tra lại lần nữa trước khi gửi request.
    if (!requireUserName() || !userName) return;

    const input: CreateTicketInput = { title: form.title.trim(), severity: form.severity, category: form.category };
    if (form.description) input.description = form.description;
    if (form.assignee) input.assignee = form.assignee;

    setSubmitting(true);
    try {
      const res = await fetch("/api/tickets", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Name": userName },
        body: JSON.stringify(input),
      });

      if (res.ok) {
        resetAndClose();
        router.refresh(); // làm mới danh sách/board đang hiển thị phía sau
        return;
      }

      const body: Partial<ErrorResponse> = await res.json().catch(() => ({}));
      setFormError(body.reason ?? body.detail ?? `Tạo ticket thất bại (HTTP ${res.status})`);
    } catch {
      setFormError("Không thể kết nối tới máy chủ, thử lại.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div className="w-full max-w-md rounded-lg border border-zinc-200 bg-white p-6 shadow-lg dark:border-zinc-800 dark:bg-zinc-900">
        <h2 className="text-lg font-semibold">Tạo ticket</h2>
        <form onSubmit={handleSubmit} className="mt-4 flex flex-col gap-3">
          {formError && (
            <p role="alert" className="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-200">
              {formError}
            </p>
          )}

          <label className="flex flex-col gap-1 text-sm">
            Tiêu đề*
            <input
              autoFocus
              value={form.title}
              maxLength={TITLE_MAX_LENGTH}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              className="rounded border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800"
            />
            {fieldErrors.title && <span className="text-red-600 dark:text-red-400">{fieldErrors.title}</span>}
          </label>

          <label className="flex flex-col gap-1 text-sm">
            Mô tả
            <textarea
              value={form.description}
              maxLength={DESCRIPTION_MAX_LENGTH}
              onChange={(event) => setForm({ ...form, description: event.target.value })}
              rows={3}
              className="rounded border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800"
            />
            {fieldErrors.description && <span className="text-red-600 dark:text-red-400">{fieldErrors.description}</span>}
          </label>

          <fieldset className="flex flex-col gap-1 text-sm">
            <legend>Mức độ</legend>
            <div className="flex flex-wrap gap-3">
              {SEVERITY_VALUES.map((value) => (
                <label key={value} className="flex items-center gap-1">
                  <input
                    type="radio"
                    name="severity"
                    value={value}
                    checked={form.severity === value}
                    onChange={() => setForm({ ...form, severity: value })}
                  />
                  {value}
                </label>
              ))}
            </div>
          </fieldset>

          <label className="flex flex-col gap-1 text-sm">
            Phân loại
            <select
              value={form.category}
              onChange={(event) => setForm({ ...form, category: event.target.value as Category })}
              className="rounded border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800"
            >
              {CATEGORY_VALUES.map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </label>

          <label className="flex flex-col gap-1 text-sm">
            Người xử lý
            <input
              value={form.assignee}
              maxLength={ASSIGNEE_MAX_LENGTH}
              onChange={(event) => setForm({ ...form, assignee: event.target.value })}
              className="rounded border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800"
              placeholder="(trống)"
            />
            {fieldErrors.assignee && <span className="text-red-600 dark:text-red-400">{fieldErrors.assignee}</span>}
          </label>

          <div className="mt-2 flex justify-end gap-2">
            <button
              type="button"
              onClick={resetAndClose}
              className="rounded px-3 py-2 text-sm text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-800"
            >
              Huỷ
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-700 disabled:opacity-50 dark:bg-white dark:text-zinc-900"
            >
              Tạo
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

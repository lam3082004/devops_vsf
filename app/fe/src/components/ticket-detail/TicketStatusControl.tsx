"use client";

import { useState, type ChangeEvent } from "react";
import { useRouter } from "next/navigation";
import { useUserName } from "@/components/UserNameProvider";
import { VALID_TRANSITIONS } from "@/components/kanban/constants";
import { parseErrorBody } from "@/components/ticket-detail/errors";
import type { Ticket, TicketStatus } from "@/lib/types";
import { STATUS_LABELS } from "@/lib/labels";
import { userNameHeaders } from "@/lib/userHeader";

interface TicketStatusControlProps {
  ticket: Ticket;
}

// Đổi trạng thái (S5, PATCH /items/{id}/status). Tách khỏi phần "Sửa" các trường còn lại vì đi qua
// endpoint khác và áp dụng ngay khi chọn (không có nút Lưu riêng).
//
// `value` của <select> luôn bám theo `ticket.status` (prop, không phải state cục bộ) — cố ý: khi PATCH
// thất bại ta chỉ setError (không đổi state khác), React re-render và select tự về đúng giá trị hiện
// tại; khi PATCH thành công router.refresh() mang `ticket.status` mới xuống, select tự khớp theo, khỏi
// cần state trung gian kiểu "pending" để đồng bộ (tránh đúng kiểu useEffect-sync mà CLAUDE.md dặn tránh).
export function TicketStatusControl({ ticket }: TicketStatusControlProps) {
  const router = useRouter();
  const { userName, requireUserName } = useUserName();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const nextOptions = VALID_TRANSITIONS[ticket.status];

  // closed là trạng thái cuối (VALID_TRANSITIONS.closed rỗng) — không có gì để chuyển tới, hiện text
  // tĩnh thay vì dropdown chỉ có một lựa chọn vô nghĩa.
  if (nextOptions.length === 0) {
    return (
      <div>
        <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Trạng thái</h2>
        <p className="mt-1 font-medium">{STATUS_LABELS[ticket.status]}</p>
      </div>
    );
  }

  async function handleChange(event: ChangeEvent<HTMLSelectElement>) {
    const next = event.target.value as TicketStatus;
    if (next === ticket.status) return;

    if (!requireUserName() || !userName) return;

    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch(`/api/tickets/${ticket.id}/status`, {
        method: "PATCH",
        headers: userNameHeaders(userName),
        body: JSON.stringify({ status: next }),
      });
      if (res.ok) {
        router.refresh();
        return;
      }
      const body = await parseErrorBody(res);
      setError(body.reason ?? body.detail ?? "Không thể đổi trạng thái, thử lại.");
    } catch {
      setError("Không thể kết nối tới máy chủ, thử lại.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div>
      <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Trạng thái</h2>
      <select
        value={ticket.status}
        disabled={submitting}
        onChange={handleChange}
        className="mt-1 w-full rounded border border-zinc-300 px-3 py-2 text-sm disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
      >
        <option value={ticket.status}>{STATUS_LABELS[ticket.status]}</option>
        {nextOptions.map((status) => (
          <option key={status} value={status}>
            {STATUS_LABELS[status]}
          </option>
        ))}
      </select>
      {error && (
        <p role="alert" className="mt-1 text-sm text-red-600 dark:text-red-400">
          {error}
        </p>
      )}
    </div>
  );
}

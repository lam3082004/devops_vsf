"use client";

import Link from "next/link";
import { useDroppable } from "@dnd-kit/core";
import type { Ticket, TicketStatus } from "@/lib/types";
import { TicketCard } from "@/components/kanban/TicketCard";
import { EmptyState } from "@/components/states";

interface KanbanColumnProps {
  status: TicketStatus;
  label: string;
  items: Ticket[];
  // Số đếm thật của cột (total từ GET /items), khác items.length khi cột có > 20 ticket.
  total: number;
  // Cột này có phải đích hợp lệ của thẻ đang được kéo hay không — chỉ là gợi ý giao diện
  // (KanbanBoard tự tính từ VALID_TRANSITIONS), không thay cho việc xử lý lỗi từ backend.
  isValidDropTarget: boolean;
}

// Vùng thả (droppable) cho một cột. Cột `Closed` luôn hiện tối đa 20 thẻ mới nhất (giới hạn của
// GET /items?limit=20) nên có thêm link "Xem tất cả" sang S3 (`/tickets?status=closed`, FE-3 — chưa
// có trang, chỉ cần link đúng).
export function KanbanColumn({ status, label, items, total, isValidDropTarget }: KanbanColumnProps) {
  const { setNodeRef, isOver } = useDroppable({ id: status });

  return (
    <div
      ref={setNodeRef}
      className={`flex min-h-[16rem] flex-1 flex-col gap-2 rounded-lg border p-3 transition-colors ${
        isOver && isValidDropTarget
          ? "border-blue-400 bg-blue-50 dark:border-blue-700 dark:bg-blue-950/40"
          : isValidDropTarget
            ? "border-blue-200 bg-blue-50/40 dark:border-blue-900 dark:bg-blue-950/10"
            : "border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900/40"
      }`}
    >
      <h2 className="flex items-baseline gap-1.5 text-sm font-semibold text-zinc-700 dark:text-zinc-300">
        {label}
        <span className="font-normal text-zinc-400 dark:text-zinc-500">({total})</span>
      </h2>

      <div className="flex flex-col gap-2">
        {items.length === 0 ? (
          <EmptyState message="Không có ticket" />
        ) : (
          items.map((ticket) => <TicketCard key={ticket.id} ticket={ticket} />)
        )}
      </div>

      {status === "closed" && (
        <Link
          href="/tickets?status=closed"
          className="mt-1 text-xs text-zinc-500 underline hover:text-zinc-800 dark:text-zinc-400 dark:hover:text-zinc-100"
        >
          Xem tất cả
        </Link>
      )}
    </div>
  );
}

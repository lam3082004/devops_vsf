"use client";

import type { CSSProperties } from "react";
import Link from "next/link";
import { useDraggable } from "@dnd-kit/core";
import type { Ticket } from "@/lib/types";
import { SEVERITY_EMOJI } from "@/components/kanban/constants";
import { formatTicketAge } from "@/components/kanban/age";

interface TicketCardProps {
  ticket: Ticket;
}

// Thẻ ticket vừa kéo được (useDraggable) vừa bấm điều hướng được sang S5 (`/tickets/{id}`, FE-4 —
// chưa có trang, chỉ cần link). `activationConstraint: { distance: 8 }` khai ở KanbanBoard (nơi tạo
// sensor) là thứ cho phép hai việc này sống chung: di chuyển dưới 8px vẫn tính là click bình thường,
// vượt ngưỡng mới coi là kéo — nên Link lồng bên trong vẫn điều hướng đúng khi "bấm không kéo".
export function TicketCard({ ticket }: TicketCardProps) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: ticket.id,
    // Nguồn xác thực trạng thái hiện tại của thẻ khi thả (xem findTicketStatus ở KanbanBoard) —
    // data ở đây chỉ để tham khảo nhanh, không phải chỗ đọc chính.
    data: { status: ticket.status },
  });

  const style: CSSProperties = {
    transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined,
    opacity: isDragging ? 0.5 : 1,
    // Đang kéo thì nổi lên trên các thẻ khác, tránh bị cột/thẻ kế bên che khi di chuyển qua.
    zIndex: isDragging ? 10 : undefined,
  };

  // Critical đang mở → viền đỏ nổi bật. "Đang mở" khớp đúng định nghĩa open_critical ở GET /stats
  // (app/be/Repositories/TicketRepository.cs: WHERE severity = critical AND status = open) — CHỈ
  // status "open", không tính "in_progress".
  const isOpenCritical = ticket.severity === "critical" && ticket.status === "open";

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      className={`touch-none rounded border bg-white p-3 text-sm shadow-sm dark:bg-zinc-900 ${
        isOpenCritical
          ? "border-red-400 ring-1 ring-red-400 dark:border-red-700 dark:ring-red-700"
          : "border-zinc-200 dark:border-zinc-800"
      }`}
    >
      <Link href={`/tickets/${ticket.id}`} className="flex flex-col gap-1">
        <span className="flex items-center gap-1.5 font-medium text-zinc-900 dark:text-zinc-100">
          <span aria-hidden>{SEVERITY_EMOJI[ticket.severity]}</span>
          {ticket.title}
        </span>
        <span className="text-xs text-zinc-500 dark:text-zinc-400">
          {ticket.category} · {formatTicketAge(ticket.created_at)}
          {ticket.assignee && <> · @{ticket.assignee}</>}
        </span>
      </Link>
    </div>
  );
}

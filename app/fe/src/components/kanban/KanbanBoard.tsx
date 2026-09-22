"use client";

import { useCallback, useState } from "react";
import {
  DndContext,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import type { DragEndEvent, DragStartEvent } from "@dnd-kit/core";
import type { ErrorResponse, Ticket, TicketStatus } from "@/lib/types";
import { useUserName } from "@/components/UserNameProvider";
import { COLUMNS, VALID_TRANSITIONS } from "@/components/kanban/constants";
import { KanbanColumn } from "@/components/kanban/KanbanColumn";
import { Toast } from "@/components/kanban/Toast";
import type { KanbanColumnsData } from "@/components/kanban/types";

interface KanbanBoardProps {
  columns: KanbanColumnsData;
}

type TicketsByStatus = Record<TicketStatus, Ticket[]>;
type TotalsByStatus = Record<TicketStatus, number>;

function toItemsByStatus(data: KanbanColumnsData): TicketsByStatus {
  return {
    open: data.open.items,
    in_progress: data.in_progress.items,
    resolved: data.resolved.items,
    closed: data.closed.items,
  };
}

function toTotalsByStatus(data: KanbanColumnsData): TotalsByStatus {
  return {
    open: data.open.total,
    in_progress: data.in_progress.total,
    resolved: data.resolved.total,
    closed: data.closed.total,
  };
}

// Tìm cột hiện tại của một ticket từ state cục bộ — nguồn xác thực duy nhất khi bắt đầu/kết thúc kéo
// (không dựng lại từ event.active.data, vì data đó chỉ chụp lúc component TicketCard render, có thể
// lệch nếu state đã đổi từ một lần kéo trước đó trong cùng phiên).
function findTicketStatus(columns: TicketsByStatus, ticketId: number): TicketStatus | null {
  for (const status of Object.keys(columns) as TicketStatus[]) {
    if (columns[status].some((ticket) => ticket.id === ticketId)) return status;
  }
  return null;
}

// Di chuyển một ticket giữa 2 cột, tính từ `prev` truyền vào (không phải snapshot chụp sẵn) — dùng
// cho cả cập nhật lạc quan lẫn hoàn tác, để 2 lượt kéo chồng lấp (thẻ A đang chờ PATCH, thẻ B kéo
// tiếp trước khi A trả lời) compose đúng thay vì lượt hoàn tác sau ghi đè mất lượt thành công trước.
function moveTicket(
  prev: TicketsByStatus,
  ticketId: number,
  from: TicketStatus,
  to: TicketStatus,
  ticket: Ticket
): TicketsByStatus {
  return {
    ...prev,
    [from]: prev[from].filter((t) => t.id !== ticketId),
    [to]: [...prev[to], ticket],
  };
}

function shiftTotals(
  prev: TotalsByStatus,
  from: TicketStatus,
  to: TicketStatus,
  delta: number
): TotalsByStatus {
  return {
    ...prev,
    [from]: Math.max(0, prev[from] - delta),
    [to]: prev[to] + delta,
  };
}

async function parseErrorBody(res: Response): Promise<Partial<ErrorResponse>> {
  try {
    const data: unknown = await res.json();
    if (data && typeof data === "object" && "error" in data) {
      return data as ErrorResponse;
    }
  } catch {
    // Body không phải JSON hợp lệ — rơi về thông báo chung ở nơi gọi.
  }
  return {};
}

// Bảng kanban (FE-2, S2). Nhận dữ liệu 4 cột từ server component (page.tsx) rồi giữ state cục bộ để
// kéo-thả cập nhật lạc quan ngay trên giao diện, không cần re-fetch toàn bộ sau mỗi lần thả.
export function KanbanBoard({ columns: initialColumns }: KanbanBoardProps) {
  const [columns, setColumns] = useState<TicketsByStatus>(() => toItemsByStatus(initialColumns));
  const [totals, setTotals] = useState<TotalsByStatus>(() => toTotalsByStatus(initialColumns));
  const [draggingStatus, setDraggingStatus] = useState<TicketStatus | null>(null);
  const [toast, setToast] = useState<{ id: number; message: string } | null>(null);
  const { userName, requireUserName } = useUserName();

  // useCallback để Toast (effect phụ thuộc onClose) không tự reset đồng hồ ẩn mỗi khi KanbanBoard
  // render lại vì lý do khác (vd đang kéo một thẻ khác).
  const closeToast = useCallback(() => setToast(null), []);

  // distance: 8 — ngưỡng phân biệt "bấm mở ticket" và "bắt đầu kéo" (xem TicketCard.tsx: Link lồng
  // trong thẻ draggable chỉ điều hướng đúng khi pointer gần như không di chuyển).
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));

  function handleDragStart(event: DragStartEvent) {
    setDraggingStatus(findTicketStatus(columns, event.active.id as number));
  }

  function handleDragCancel() {
    setDraggingStatus(null);
  }

  async function handleDragEnd(event: DragEndEvent) {
    setDraggingStatus(null);
    const { active, over } = event;
    if (!over) return; // thả ra ngoài mọi vùng droppable → không làm gì

    const ticketId = active.id as number;
    const sourceStatus = findTicketStatus(columns, ticketId);
    const targetStatus = over.id as TicketStatus;
    if (!sourceStatus || sourceStatus === targetStatus) return; // thả lại đúng cột cũ → không làm gì

    const ticket = columns[sourceStatus].find((t) => t.id === ticketId);
    if (!ticket) return;

    // US-01: chưa có tên thì mọi thao tác ghi bị chặn — kiểm tra TRƯỚC khi đụng vào state, để không
    // cần optimistic-update rồi hoàn tác cho nhánh này (requireUserName() tự mở NameGate khi cần).
    if (!requireUserName() || !userName) return;

    const movedTicket: Ticket = { ...ticket, status: targetStatus };
    setColumns((prev) => moveTicket(prev, ticketId, sourceStatus, targetStatus, movedTicket));
    setTotals((prev) => shiftTotals(prev, sourceStatus, targetStatus, 1));

    try {
      const res = await fetch(`/api/tickets/${ticketId}/status`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-User-Name": userName },
        body: JSON.stringify({ status: targetStatus }),
      });
      if (!res.ok) {
        // Mọi lỗi (409 invalid_transition, 400, 404, 5xx...) đều hoàn tác + báo lý do — backend là
        // trọng tài cuối cùng, kể cả khi UI đã gợi ý đúng cột lúc kéo (vd hai người cùng thao tác).
        // Hoàn tác tính từ `prev` tại đúng lúc PATCH này trả lời (không phải snapshot chụp lúc bắt
        // đầu), để không ghi đè mất một lượt kéo khác đã thành công trong lúc chờ PATCH này.
        const body = await parseErrorBody(res);
        setColumns((prev) => moveTicket(prev, ticketId, targetStatus, sourceStatus, ticket));
        setTotals((prev) => shiftTotals(prev, targetStatus, sourceStatus, 1));
        setToast({
          id: Date.now(),
          message: body.reason ?? body.detail ?? "Không thể đổi trạng thái, thử lại.",
        });
      }
      // ok → giữ nguyên state lạc quan (đã đúng), không cần re-fetch toàn bộ.
    } catch {
      // Lỗi mạng (không nhận được response) — xử lý như lỗi HTTP: hoàn tác + toast.
      setColumns((prev) => moveTicket(prev, ticketId, targetStatus, sourceStatus, ticket));
      setTotals((prev) => shiftTotals(prev, targetStatus, sourceStatus, 1));
      setToast({ id: Date.now(), message: "Không thể đổi trạng thái, thử lại." });
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onDragCancel={handleDragCancel}
    >
      <div className="flex flex-col gap-3 md:flex-row">
        {COLUMNS.map(({ status, label }) => (
          <KanbanColumn
            key={status}
            status={status}
            label={label}
            items={columns[status]}
            total={totals[status]}
            isValidDropTarget={
              draggingStatus !== null &&
              draggingStatus !== status &&
              VALID_TRANSITIONS[draggingStatus].includes(status)
            }
          />
        ))}
      </div>
      {toast && <Toast key={toast.id} message={toast.message} onClose={closeToast} />}
    </DndContext>
  );
}

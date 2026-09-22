// Trang chủ — bảng kanban (S2, FE-2). Server component: gọi thẳng lib/api.ts (không qua BFF vì chỉ
// đọc dữ liệu, không cần X-User-Name) rồi giao 4 cột cho KanbanBoard (client) render + kéo thả.
import { ApiError, getTickets } from "@/lib/api";
import { ErrorBanner, ForbiddenState } from "@/components/states";
import { KanbanBoard } from "@/components/kanban/KanbanBoard";
import type { KanbanColumnsData } from "@/components/kanban/types";

export default async function Home() {
  let columns: KanbanColumnsData;

  try {
    // Không có endpoint nhóm theo status — gọi GET /items 4 lần song song, mỗi lần một status
    // (xem "Cách frontend dựng kanban" ở api-spec.md).
    const [openList, inProgressList, resolvedList, closedList] = await Promise.all([
      getTickets({ status: "open", limit: 20 }),
      getTickets({ status: "in_progress", limit: 20 }),
      getTickets({ status: "resolved", limit: 20 }),
      getTickets({ status: "closed", limit: 20 }),
    ]);

    columns = {
      open: { items: openList.items, total: openList.total },
      in_progress: { items: inProgressList.items, total: inProgressList.total },
      resolved: { items: resolvedList.items, total: resolvedList.total },
      closed: { items: closedList.items, total: closedList.total },
    };
  } catch (error) {
    if (error instanceof ApiError && error.status === 403) {
      return (
        <main className="mx-auto max-w-5xl px-6 py-6">
          <ForbiddenState />
        </main>
      );
    }
    // Server component không tự re-fetch được từ đây; ErrorBanner (client) tự lo nút "Thử lại" bằng router.refresh().
    const message = error instanceof ApiError ? error.message : "Không thể tải bảng kanban.";
    return (
      <main className="mx-auto max-w-5xl px-6 py-6">
        <ErrorBanner message={message} />
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-6">
      <h1 className="mb-4 text-2xl font-semibold tracking-tight">Bảng ticket</h1>
      <KanbanBoard columns={columns} />
    </main>
  );
}

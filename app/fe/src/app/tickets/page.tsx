// Trang danh sách ticket (S3, FE-3). Server component: gọi thẳng lib/api.ts (chỉ đọc, không cần
// X-User-Name), parse searchParams an toàn bằng components/tickets/query.ts trước khi gọi backend.
import { ApiError, getTickets } from "@/lib/api";
import { EmptyState, ErrorBanner, ForbiddenState } from "@/components/states";
import { TicketFilters } from "@/components/tickets/TicketFilters";
import { TicketTable } from "@/components/tickets/TicketTable";
import { Pagination } from "@/components/tickets/Pagination";
import { parseTicketListParams } from "@/components/tickets/query";
import type { TicketList } from "@/lib/types";

export default async function TicketsPage(props: PageProps<"/tickets">) {
  const { query, page } = parseTicketListParams(await props.searchParams);

  let list: TicketList;
  try {
    list = await getTickets(query);
  } catch (error) {
    if (error instanceof ApiError && error.status === 403) {
      return (
        <main className="mx-auto max-w-5xl px-6 py-6">
          <ForbiddenState />
        </main>
      );
    }
    // Server component không tự re-fetch được từ đây; ErrorBanner (client) tự lo nút "Thử lại" bằng router.refresh().
    const message = error instanceof ApiError ? error.message : "Không thể tải danh sách ticket.";
    return (
      <main className="mx-auto max-w-5xl px-6 py-6">
        <ErrorBanner message={message} />
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-6">
      <h1 className="mb-4 text-2xl font-semibold tracking-tight">Danh sách ticket</h1>
      <TicketFilters query={query} />
      {list.items.length === 0 ? (
        <EmptyState message="Không tìm thấy ticket phù hợp bộ lọc" />
      ) : (
        <TicketTable tickets={list.items} />
      )}
      <Pagination query={query} page={page} total={list.total} limit={list.limit} />
    </main>
  );
}

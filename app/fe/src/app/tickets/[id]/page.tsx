// Trang chi tiết ticket (S5, FE-4). Server component: HAI lời gọi HTTP riêng biệt (GET /items/{id} và
// GET /items/{id}/comments) chạy song song bằng Promise.all — KHÔNG gộp thành một, đúng yêu cầu
// docs/docs_app/plan/fe.md mục FE-4 và api-spec.md ("Trang chi tiết ticket cần hai lời gọi riêng").
import { notFound } from "next/navigation";
import { ApiError, getComments, getTicket } from "@/lib/api";
import { ErrorBanner, ForbiddenState } from "@/components/states";
import { TicketDetailView } from "@/components/ticket-detail/TicketDetailView";
import type { CommentList, TicketDetail } from "@/lib/types";

export default async function TicketDetailPage(props: PageProps<"/tickets/[id]">) {
  const { id } = await props.params;
  const ticketId = Number.parseInt(id, 10);

  // id không phải số nguyên hợp lệ → coi như không tìm thấy, khỏi cần gọi backend (khớp cách BFF
  // src/lib/http.ts parseTicketId từ chối cùng dạng input).
  if (!/^\d+$/.test(id)) {
    notFound();
  }

  let detail: TicketDetail;
  let commentList: CommentList;
  try {
    [detail, commentList] = await Promise.all([getTicket(ticketId), getComments(ticketId)]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      notFound();
    }
    if (error instanceof ApiError && error.status === 403) {
      return (
        <main className="mx-auto max-w-5xl px-6 py-6">
          <ForbiddenState />
        </main>
      );
    }
    // Server component không tự re-fetch được từ đây; ErrorBanner (client) tự lo nút "Thử lại" bằng router.refresh().
    const message = error instanceof ApiError ? error.message : "Không thể tải chi tiết ticket.";
    return (
      <main className="mx-auto max-w-5xl px-6 py-6">
        <ErrorBanner message={message} />
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-6">
      <TicketDetailView
        ticket={detail.ticket}
        activities={detail.activities}
        comments={commentList.comments}
      />
    </main>
  );
}

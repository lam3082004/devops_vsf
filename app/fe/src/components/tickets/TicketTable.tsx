import Link from "next/link";
import type { Ticket } from "@/lib/types";
import { SEVERITY_EMOJI } from "@/components/kanban/constants";
import { formatTicketAge } from "@/components/kanban/age";
import { CATEGORY_LABELS, SEVERITY_LABELS, STATUS_LABELS } from "@/lib/labels";

interface TicketTableProps {
  tickets: Ticket[];
}

// Bảng danh sách (S3). Mỗi ô bọc riêng bằng <Link> (không bọc cả <tr> bằng <a> — không hợp lệ HTML)
// để cả dòng bấm được mà vẫn là Server Component thuần, không cần JS.
export function TicketTable({ tickets }: TicketTableProps) {
  return (
    <table className="w-full border-collapse text-sm">
      <thead>
        <tr className="border-b border-zinc-200 text-left text-zinc-500 dark:border-zinc-800 dark:text-zinc-400">
          <th className="px-2 py-2 font-medium">#</th>
          <th className="px-2 py-2 font-medium">Tiêu đề</th>
          <th className="px-2 py-2 font-medium">Mức độ</th>
          <th className="px-2 py-2 font-medium">Trạng thái</th>
          <th className="px-2 py-2 font-medium">Người xử lý</th>
          <th className="px-2 py-2 font-medium">Phân loại</th>
          <th className="px-2 py-2 font-medium">Tạo</th>
        </tr>
      </thead>
      <tbody>
        {tickets.map((ticket) => (
          <tr
            key={ticket.id}
            className="border-b border-zinc-100 hover:bg-zinc-50 dark:border-zinc-900 dark:hover:bg-zinc-900/60"
          >
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                {ticket.id}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block font-medium text-zinc-900 dark:text-zinc-100">
                {ticket.title}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                <span aria-hidden>{SEVERITY_EMOJI[ticket.severity]}</span> {SEVERITY_LABELS[ticket.severity]}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                {STATUS_LABELS[ticket.status]}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                {ticket.assignee ?? "—"}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                {CATEGORY_LABELS[ticket.category]}
              </Link>
            </td>
            <td className="px-2 py-2">
              <Link href={`/tickets/${ticket.id}`} className="block">
                {formatTicketAge(ticket.created_at)}
              </Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

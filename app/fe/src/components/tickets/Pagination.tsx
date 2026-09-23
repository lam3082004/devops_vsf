import Link from "next/link";
import type { TicketQuery } from "@/lib/types";
import { ticketListHref } from "@/components/tickets/query";

interface PaginationProps {
  query: TicketQuery;
  page: number;
  total: number;
  limit: number;
}

// Điều hướng trang (S3): "‹ Trước"/"Sau ›" ẩn khi ở biên thay vì hiện nút vô hiệu hoá — Link không có
// cách "disabled" hợp lệ về mặt ngữ nghĩa, ẩn hẳn rõ ràng hơn.
export function Pagination({ query, page, total, limit }: PaginationProps) {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  const offset = (page - 1) * limit;

  return (
    <div className="mt-4 flex items-center justify-end gap-4 text-sm">
      {page > 1 && (
        <Link href={ticketListHref(query, Math.max(0, offset - limit))} className="text-zinc-600 hover:underline dark:text-zinc-400">
          ‹ Trước
        </Link>
      )}
      <span className="text-zinc-500 dark:text-zinc-400">
        Trang {page}/{totalPages}
      </span>
      {page < totalPages && (
        <Link href={ticketListHref(query, offset + limit)} className="text-zinc-600 hover:underline dark:text-zinc-400">
          Sau ›
        </Link>
      )}
    </div>
  );
}

import { formatActivityLabel } from "@/components/ticket-detail/activity-label";
import { formatDateTime } from "@/components/ticket-detail/format";
import type { Activity } from "@/lib/types";

interface TicketHistoryListProps {
  activities: Activity[];
}

// Lịch sử thay đổi (S5). API trả `activities` tăng dần theo thời gian (api-spec.md) — đảo ngược CHỈ
// lúc hiển thị (mới nhất lên trên, theo wire-frame.md) bằng cách copy mảng, không sửa `activities` gốc.
export function TicketHistoryList({ activities }: TicketHistoryListProps) {
  const newestFirst = [...activities].reverse();

  return (
    <div>
      <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Lịch sử</h2>
      <ul className="mt-1 flex flex-col gap-1 text-sm">
        {newestFirst.map((activity) => (
          <li key={activity.id} className="text-zinc-700 dark:text-zinc-300">
            <span className="text-zinc-400 dark:text-zinc-500">{formatDateTime(activity.created_at)}</span>{" "}
            {formatActivityLabel(activity)}{" "}
            <span className="text-zinc-400 dark:text-zinc-500">({activity.actor})</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

// Trang thống kê (S6, FE-5, PRD US-07). Server Component: gọi thẳng lib/api.ts (chỉ đọc, không cần
// X-User-Name), cùng khung 403/lỗi với tickets/page.tsx.
import { ApiError, getStats } from "@/lib/api";
import { ErrorBanner, ForbiddenState } from "@/components/states";
import { DistributionBar } from "@/components/stats/DistributionBar";
import { formatResolutionMinutes } from "@/components/stats/formatResolutionMinutes";
import { COLUMNS, SEVERITY_EMOJI } from "@/components/kanban/constants";
import { ticketListHref } from "@/components/tickets/query";
import type { Severity, Stats } from "@/lib/types";
import { SEVERITY_LABELS } from "@/lib/labels";

// Thứ tự + màu theo wire-frame S6 (🔴 critical, 🟠 high, 🟡 medium, 🟢 low) — KHÁC thứ tự SEVERITY_VALUES
// của query.ts (low → critical), nên khai riêng ở đây thay vì tái dùng mảng đó.
const SEVERITY_ORDER: readonly Severity[] = ["critical", "high", "medium", "low"];

const STATUS_COLOR: Record<(typeof COLUMNS)[number]["status"], string> = {
  open: "bg-sky-500",
  in_progress: "bg-amber-500",
  resolved: "bg-emerald-500",
  closed: "bg-zinc-400 dark:bg-zinc-500",
};

const SEVERITY_COLOR: Record<Severity, string> = {
  critical: "bg-red-500",
  high: "bg-orange-500",
  medium: "bg-yellow-500",
  low: "bg-green-500",
};

export default async function StatsPage() {
  let stats: Stats;
  try {
    stats = await getStats();
  } catch (error) {
    if (error instanceof ApiError && error.status === 403) {
      return (
        <main className="mx-auto max-w-5xl px-6 py-6">
          <ForbiddenState />
        </main>
      );
    }
    // Server component không tự re-fetch được từ đây; ErrorBanner (client) tự lo nút "Thử lại" bằng router.refresh().
    const message = error instanceof ApiError ? error.message : "Không thể tải thống kê.";
    return (
      <main className="mx-auto max-w-5xl px-6 py-6">
        <ErrorBanner message={message} />
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-5xl px-6 py-6">
      <h1 className="mb-4 text-2xl font-semibold tracking-tight">Thống kê</h1>

      <div className="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatBox label="Tổng" value={String(stats.total)} />
        <StatBox label="Critical đang mở" value={String(stats.open_critical)} />
        <StatBox
          label="TB xử lý"
          value={formatResolutionMinutes(stats.avg_resolution_minutes)}
        />
      </div>

      <div className="flex flex-col gap-6">
        <DistributionBar
          title="Theo trạng thái"
          segments={COLUMNS.map((column) => ({
            key: column.status,
            label: column.label,
            count: stats.by_status[column.status],
            href: ticketListHref({ status: column.status }, 0),
            color: STATUS_COLOR[column.status],
          }))}
        />

        <DistributionBar
          title="Theo mức độ"
          segments={SEVERITY_ORDER.map((severity) => ({
            key: severity,
            label: SEVERITY_LABELS[severity],
            icon: SEVERITY_EMOJI[severity],
            count: stats.by_severity[severity],
            href: ticketListHref({ severity }, 0),
            color: SEVERITY_COLOR[severity],
          }))}
        />
      </div>
    </main>
  );
}

interface StatBoxProps {
  label: string;
  value: string;
}

// Ô số bo góc viền — cùng tinh thần với components/states (border zinc, biến thể dark).
function StatBox({ label, value }: StatBoxProps) {
  return (
    <div className="flex flex-col gap-1 rounded border border-zinc-300 px-4 py-3 dark:border-zinc-700">
      <span className="text-xs text-zinc-500 dark:text-zinc-400">{label}</span>
      <span className="text-xl font-semibold text-zinc-900 dark:text-zinc-100">{value}</span>
    </div>
  );
}

// Hàm thuần cho danh sách ticket (S3, FE-3): đọc searchParams thô từ URL thành TicketQuery an toàn,
// và dựng ngược lại URL từ TicketQuery. Tách khỏi page.tsx để component client (bộ lọc, phân trang)
// dùng chung mà không phải import lib/api.ts (server-only).
import type { Category, Severity, TicketQuery, TicketStatus } from "@/lib/types";

export const STATUS_VALUES: readonly TicketStatus[] = [
  "open",
  "in_progress",
  "resolved",
  "closed",
];
export const SEVERITY_VALUES: readonly Severity[] = ["low", "medium", "high", "critical"];
export const CATEGORY_VALUES: readonly Category[] = [
  "infra",
  "app",
  "database",
  "network",
  "security",
  "other",
];

export const LIMIT_OPTIONS = [20, 50, 100] as const;
export const DEFAULT_LIMIT = 20;
export const MAX_Q_LENGTH = 100;

type RawSearchParams = Record<string, string | string[] | undefined>;

// searchParams có thể lặp key (`?status=open&status=closed`) — chỉ lấy giá trị đầu tiên, phần còn lại
// coi như không gõ (URL không có quy ước "nhiều giá trị" cho các field này).
function firstValue(raw: string | string[] | undefined): string | undefined {
  return Array.isArray(raw) ? raw[0] : raw;
}

function parseEnum<T extends string>(
  raw: string | string[] | undefined,
  values: readonly T[]
): T | undefined {
  const value = firstValue(raw);
  return value !== undefined && (values as readonly string[]).includes(value)
    ? (value as T)
    : undefined;
}

function parseIntInRange(
  raw: string | string[] | undefined,
  fallback: number,
  min: number,
  max: number
): number {
  const value = firstValue(raw);
  if (value === undefined) return fallback;
  const n = Number.parseInt(value, 10);
  if (!Number.isFinite(n) || n < min || n > max) return fallback;
  return n;
}

export function parseTicketListParams(raw: RawSearchParams): {
  query: TicketQuery;
  page: number;
} {
  const status = parseEnum(raw.status, STATUS_VALUES);
  const severity = parseEnum(raw.severity, SEVERITY_VALUES);
  const category = parseEnum(raw.category, CATEGORY_VALUES);

  const qRaw = firstValue(raw.q);
  const q = qRaw !== undefined ? qRaw.slice(0, MAX_Q_LENGTH) : undefined;

  const limit = parseIntInRange(raw.limit, DEFAULT_LIMIT, 1, 100);
  const offset = parseIntInRange(raw.offset, 0, 0, Number.MAX_SAFE_INTEGER);

  // unassigned=true và assignee cùng xuất hiện trên URL (link cũ/gõ tay) → backend từ chối cả hai cùng
  // lúc (400), nên ưu tiên unassigned và bỏ assignee ở đây thay vì để lỗi lọt tới getTickets().
  const unassigned = firstValue(raw.unassigned) === "true";
  const assigneeRaw = firstValue(raw.assignee);
  const assignee = !unassigned && assigneeRaw ? assigneeRaw : undefined;

  const query: TicketQuery = {
    ...(status && { status }),
    ...(severity && { severity }),
    ...(category && { category }),
    ...(assignee && { assignee }),
    ...(unassigned && { unassigned: true }),
    ...(q && { q }),
    limit,
    offset,
  };

  return { query, page: Math.floor(offset / limit) + 1 };
}

export function ticketListHref(query: TicketQuery, offset: number): string {
  const params = new URLSearchParams();
  if (query.status) params.set("status", query.status);
  if (query.severity) params.set("severity", query.severity);
  if (query.category) params.set("category", query.category);
  if (query.unassigned) {
    params.set("unassigned", "true");
  } else if (query.assignee) {
    params.set("assignee", query.assignee);
  }
  if (query.q) params.set("q", query.q);
  const limit = query.limit ?? DEFAULT_LIMIT;
  if (limit !== DEFAULT_LIMIT) params.set("limit", String(limit));
  if (offset > 0) params.set("offset", String(offset));

  const qs = params.toString();
  return qs ? `/tickets?${qs}` : "/tickets";
}

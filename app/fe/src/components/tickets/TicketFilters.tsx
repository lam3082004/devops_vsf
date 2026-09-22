"use client";

import { useState, type ChangeEvent, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import type { Category, Severity, TicketQuery, TicketStatus } from "@/lib/types";
import {
  CATEGORY_VALUES,
  DEFAULT_LIMIT,
  LIMIT_OPTIONS,
  MAX_Q_LENGTH,
  SEVERITY_VALUES,
  STATUS_VALUES,
  ticketListHref,
} from "@/components/tickets/query";
import { CATEGORY_LABELS, SEVERITY_LABELS, STATUS_LABELS } from "@/lib/labels";

interface TicketFiltersProps {
  query: TicketQuery;
}

interface FilterOverrides {
  status?: TicketStatus | "";
  severity?: Severity | "";
  category?: Category | "";
  assignee?: string;
  unassigned?: boolean;
  q?: string;
  limit?: number;
}

// Bộ lọc danh sách ticket (S3). Không có endpoint liệt kê assignee nên `assignee`/`unassigned` dùng ô
// nhập text + checkbox thay vì dropdown như wire-frame vẽ (wire-frame chỉ là mock ASCII, không phải
// hợp đồng dữ liệu thật).
export function TicketFilters({ query }: TicketFiltersProps) {
  const router = useRouter();

  const [status, setStatus] = useState<TicketStatus | "">(query.status ?? "");
  const [severity, setSeverity] = useState<Severity | "">(query.severity ?? "");
  const [category, setCategory] = useState<Category | "">(query.category ?? "");
  const [assignee, setAssignee] = useState(query.assignee ?? "");
  const [unassigned, setUnassigned] = useState(query.unassigned ?? false);
  const [q, setQ] = useState(query.q ?? "");
  const [limit, setLimit] = useState(query.limit ?? DEFAULT_LIMIT);

  // Resync state theo `query` mỗi khi prop đổi mà component không remount (router.push trong cùng route
  // /tickets, kể cả Back/Forward trình duyệt) — useState ban đầu chỉ đọc `query` lúc mount nên không tự
  // cập nhật theo, khiến <select> hiển thị sai so với dữ liệu đang hiển thị. Set state ngay trong lúc
  // render (thay vì trong useEffect) theo đúng pattern React khuyến nghị cho "adjust state khi prop đổi":
  // page.tsx (server component) tạo `query` mới mỗi lần điều hướng nên so sánh reference là đủ, và cách
  // này tránh lint rule react-hooks/set-state-in-effect (gọi setState đồng bộ trong effect body).
  const [prevQuery, setPrevQuery] = useState(query);
  if (prevQuery !== query) {
    setPrevQuery(query);
    setStatus(query.status ?? "");
    setSeverity(query.severity ?? "");
    setCategory(query.category ?? "");
    setAssignee(query.assignee ?? "");
    setUnassigned(query.unassigned ?? false);
    setQ(query.q ?? "");
    setLimit(query.limit ?? DEFAULT_LIMIT);
  }

  // Đổi bất kỳ bộ lọc nào cũng phải reset offset về 0 — tổng số trang có thể đổi theo bộ lọc mới, giữ
  // offset cũ dễ nhảy tới trang trống. Dùng `in` để phân biệt "key có mặt (kể cả giá trị rỗng/undefined,
  // nghĩa là xoá filter)" với "key vắng mặt (giữ nguyên giá trị hiện tại)" — `??` không phân biệt được
  // 2 trường hợp này khi giá trị truyền vào chính là `undefined`, gây bug không xoá được filter khi chọn
  // lại "Tất cả" (chọn "Tất cả" → next.status === undefined → ?? rơi về state cũ thay vì xoá).
  function navigate(next: FilterOverrides) {
    const resolvedStatus = "status" in next ? next.status : status;
    const resolvedSeverity = "severity" in next ? next.severity : severity;
    const resolvedCategory = "category" in next ? next.category : category;
    const resolvedUnassigned = "unassigned" in next ? (next.unassigned ?? false) : unassigned;
    const resolvedAssignee = resolvedUnassigned
      ? undefined
      : (("assignee" in next ? next.assignee : assignee) || undefined);
    const resolvedQ = "q" in next ? next.q : q;
    const resolvedLimit = "limit" in next ? (next.limit ?? limit) : limit;

    router.push(
      ticketListHref(
        {
          status: resolvedStatus || undefined,
          severity: resolvedSeverity || undefined,
          category: resolvedCategory || undefined,
          assignee: resolvedAssignee,
          unassigned: resolvedUnassigned,
          q: resolvedQ || undefined,
          limit: resolvedLimit,
        },
        0
      )
    );
  }

  function handleUnassignedChange(event: ChangeEvent<HTMLInputElement>) {
    const checked = event.target.checked;
    setUnassigned(checked);
    if (checked) setAssignee(""); // tick "Chưa phân công" thì xoá ngay ô assignee, tránh gửi cả hai lên backend (400)
    navigate({ unassigned: checked });
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    navigate({});
  }

  return (
    <form onSubmit={handleSubmit} className="mb-4 flex flex-wrap items-end gap-3 text-sm">
      <label className="flex flex-col gap-1">
        Trạng thái
        <select
          value={status}
          onChange={(event) => {
            const value = event.target.value as TicketStatus | "";
            setStatus(value);
            navigate({ status: value });
          }}
          className="rounded border border-zinc-300 px-2 py-1.5 dark:border-zinc-700 dark:bg-zinc-800"
        >
          <option value="">Tất cả</option>
          {STATUS_VALUES.map((value) => (
            <option key={value} value={value}>
              {STATUS_LABELS[value]}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1">
        Mức độ
        <select
          value={severity}
          onChange={(event) => {
            const value = event.target.value as Severity | "";
            setSeverity(value);
            navigate({ severity: value });
          }}
          className="rounded border border-zinc-300 px-2 py-1.5 dark:border-zinc-700 dark:bg-zinc-800"
        >
          <option value="">Tất cả</option>
          {SEVERITY_VALUES.map((value) => (
            <option key={value} value={value}>
              {SEVERITY_LABELS[value]}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1">
        Phân loại
        <select
          value={category}
          onChange={(event) => {
            const value = event.target.value as Category | "";
            setCategory(value);
            navigate({ category: value });
          }}
          className="rounded border border-zinc-300 px-2 py-1.5 dark:border-zinc-700 dark:bg-zinc-800"
        >
          <option value="">Tất cả</option>
          {CATEGORY_VALUES.map((value) => (
            <option key={value} value={value}>
              {CATEGORY_LABELS[value]}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1">
        Người xử lý
        <input
          type="text"
          value={assignee}
          disabled={unassigned}
          onChange={(event) => setAssignee(event.target.value)}
          className="rounded border border-zinc-300 px-2 py-1.5 disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800"
          placeholder="Tên..."
        />
      </label>

      <label className="flex items-center gap-1.5 pb-1.5">
        <input type="checkbox" checked={unassigned} onChange={handleUnassignedChange} />
        Chưa phân công
      </label>

      <label className="flex flex-col gap-1">
        Tìm tiêu đề
        <input
          type="text"
          value={q}
          maxLength={MAX_Q_LENGTH}
          onChange={(event) => setQ(event.target.value)}
          className="rounded border border-zinc-300 px-2 py-1.5 dark:border-zinc-700 dark:bg-zinc-800"
          placeholder="Tìm..."
        />
      </label>

      <label className="flex flex-col gap-1">
        Số dòng/trang
        <select
          value={limit}
          onChange={(event) => {
            const value = Number(event.target.value);
            setLimit(value);
            navigate({ limit: value });
          }}
          className="rounded border border-zinc-300 px-2 py-1.5 dark:border-zinc-700 dark:bg-zinc-800"
        >
          {LIMIT_OPTIONS.map((value) => (
            <option key={value} value={value}>
              {value}
            </option>
          ))}
        </select>
      </label>

      <button
        type="submit"
        className="rounded bg-zinc-900 px-3 py-1.5 text-white hover:bg-zinc-700 dark:bg-white dark:text-zinc-900"
      >
        Lọc
      </button>
    </form>
  );
}

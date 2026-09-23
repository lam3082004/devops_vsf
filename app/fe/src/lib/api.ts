// Client gọi backend .NET (app/be). CHỈ được import từ Server Component hoặc route handler trong
// src/app/api/** — không bao giờ từ "use client", vì API_BASE_URL trỏ tới địa chỉ nội bộ của backend
// và không được lộ ra trình duyệt (docs/docs_app/plan/fe.md, mục "Luật kiến trúc").
if (typeof window !== "undefined") {
  throw new Error(
    "src/lib/api.ts chỉ chạy phía server — đừng import vào component 'use client'."
  );
}

import type {
  AddCommentInput,
  Comment,
  CommentList,
  CreateTicketInput,
  ErrorResponse,
  PatchStatusInput,
  PatchTicketInput,
  Stats,
  Ticket,
  TicketDetail,
  TicketList,
  TicketQuery,
} from "@/lib/types";

// Lỗi có kiểu giữ được `error` + `reason` + status HTTP, để nơi gọi (route handler, page) quyết định
// hiện banner lỗi hay đọc `reason` (vd 409 invalid_transition cần hiện lý do cho kanban — FE-2).
// `status = 0` là quy ước riêng của client này: không nhận được response nào cả (backend sập, mất
// mạng...) — khác với backend trả lỗi có body, nhưng vẫn cần một trạng thái để UI hiện banner (US-08).
export class ApiError extends Error {
  readonly status: number;
  readonly code?: ErrorResponse["error"];
  readonly reason?: string;
  readonly detail?: string;

  constructor(status: number, body: Partial<ErrorResponse>) {
    super(
      body.reason ??
        body.detail ??
        (status === 0
          ? "Không thể kết nối tới backend."
          : `Backend trả về HTTP ${status}`)
    );
    this.name = "ApiError";
    this.status = status;
    this.code = body.error;
    this.reason = body.reason;
    this.detail = body.detail;
  }
}

// traceparent: chuyển tiếp ở MỌI lời gọi (đọc lẫn ghi) để trace nối được fe → be.
// userName: chỉ bắt buộc ở lời gọi ghi (X-User-Name), backend trả 400 nếu thiếu.
export interface ReadContext {
  traceparent?: string;
}

export interface WriteContext extends ReadContext {
  userName: string;
}

function requireBaseUrl(): string {
  const base = process.env.API_BASE_URL;
  if (!base) {
    throw new Error(
      "API_BASE_URL chua duoc cau hinh (bien moi truong phia server, xem app/fe/.env.example)"
    );
  }
  return base;
}

function isErrorResponseShape(data: unknown): data is ErrorResponse {
  return (
    typeof data === "object" &&
    data !== null &&
    "error" in data &&
    typeof (data as { error: unknown }).error === "string"
  );
}

async function parseErrorBody(res: Response): Promise<Partial<ErrorResponse>> {
  try {
    const data: unknown = await res.json();
    if (isErrorResponseShape(data)) return data;
  } catch {
    // Body không phải JSON hợp lệ — có thể là trang chặn của hạ tầng (vd 403 IP whitelist của Azure
    // App Service không đi qua ErrorResponse của app). Rơi về fallback rỗng, giữ nguyên status HTTP.
  }
  return {};
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  traceparent?: string;
  userName?: string;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const baseUrl = requireBaseUrl();
  const headers = new Headers({ Accept: "application/json" });
  if (options.traceparent) headers.set("traceparent", options.traceparent);
  if (options.userName) headers.set("X-User-Name", options.userName);

  let body: string | undefined;
  if (options.body !== undefined) {
    headers.set("Content-Type", "application/json");
    body = JSON.stringify(options.body);
  }

  let res: Response;
  try {
    // cache: "no-store" cho mọi lời gọi — dữ liệu ticket đổi liên tục, cache mặc định của Next.js
    // (fetch trong Server Component) sẽ cho ra bảng cũ.
    res = await fetch(new URL(path, baseUrl), {
      method: options.method ?? "GET",
      headers,
      body,
      cache: "no-store",
    });
  } catch {
    throw new ApiError(0, {});
  }

  if (!res.ok) {
    throw new ApiError(res.status, await parseErrorBody(res));
  }

  return (await res.json()) as T;
}

function buildTicketQuery(query: TicketQuery): string {
  const params = new URLSearchParams();
  if (query.status) params.set("status", query.status);
  if (query.severity) params.set("severity", query.severity);
  if (query.category) params.set("category", query.category);
  if (query.assignee !== undefined) params.set("assignee", query.assignee);
  if (query.unassigned) params.set("unassigned", "true");
  if (query.q !== undefined) params.set("q", query.q);
  if (query.limit !== undefined) params.set("limit", String(query.limit));
  if (query.offset !== undefined) params.set("offset", String(query.offset));
  const qs = params.toString();
  return qs ? `?${qs}` : "";
}

export async function getTickets(
  query: TicketQuery = {},
  ctx: ReadContext = {}
): Promise<TicketList> {
  return request<TicketList>(`/items${buildTicketQuery(query)}`, {
    traceparent: ctx.traceparent,
  });
}

export async function getTicket(
  id: number,
  ctx: ReadContext = {}
): Promise<TicketDetail> {
  return request<TicketDetail>(`/items/${id}`, { traceparent: ctx.traceparent });
}

export async function createTicket(
  input: CreateTicketInput,
  ctx: WriteContext
): Promise<Ticket> {
  return request<Ticket>("/items", {
    method: "POST",
    body: input,
    traceparent: ctx.traceparent,
    userName: ctx.userName,
  });
}

export async function patchTicket(
  id: number,
  input: PatchTicketInput,
  ctx: WriteContext
): Promise<Ticket> {
  return request<Ticket>(`/items/${id}`, {
    method: "PATCH",
    body: input,
    traceparent: ctx.traceparent,
    userName: ctx.userName,
  });
}

export async function patchStatus(
  id: number,
  input: PatchStatusInput,
  ctx: WriteContext
): Promise<Ticket> {
  return request<Ticket>(`/items/${id}/status`, {
    method: "PATCH",
    body: input,
    traceparent: ctx.traceparent,
    userName: ctx.userName,
  });
}

export async function getComments(
  id: number,
  ctx: ReadContext = {}
): Promise<CommentList> {
  return request<CommentList>(`/items/${id}/comments`, {
    traceparent: ctx.traceparent,
  });
}

export async function addComment(
  id: number,
  input: AddCommentInput,
  ctx: WriteContext
): Promise<Comment> {
  return request<Comment>(`/items/${id}/comments`, {
    method: "POST",
    body: input,
    traceparent: ctx.traceparent,
    userName: ctx.userName,
  });
}

export async function getStats(ctx: ReadContext = {}): Promise<Stats> {
  return request<Stats>("/stats", { traceparent: ctx.traceparent });
}

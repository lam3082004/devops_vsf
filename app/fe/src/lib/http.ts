// Tiện ích dùng chung cho route handler BFF (src/app/api/**) — tránh lặp lại logic đọc header và
// chuyển ApiError thành ErrorResponse ở mỗi route ghi.
import { NextRequest, NextResponse } from "next/server";
import { ApiError } from "@/lib/api";
import type { ErrorResponse } from "@/lib/types";

export function readTraceparent(request: NextRequest): string | undefined {
  return request.headers.get("traceparent") ?? undefined;
}

// Backend là trọng tài cuối cùng cho độ dài tên (1–50 ký tự, api-spec.md); BFF chỉ chặn trường hợp
// thiếu hẳn header để trả lỗi sớm, đỡ một vòng round-trip khi FE quên gắn X-User-Name.
export function requireUserName(
  request: NextRequest
): string | NextResponse<ErrorResponse> {
  const name = request.headers.get("X-User-Name");
  if (!name) {
    return NextResponse.json<ErrorResponse>(
      { error: "bad_request", reason: "Thiếu header X-User-Name" },
      { status: 400 }
    );
  }
  return name;
}

export function parseTicketId(raw: string): number | null {
  if (!/^\d+$/.test(raw)) return null;
  return Number(raw);
}

export async function readJsonBody<T>(
  request: NextRequest
): Promise<{ ok: true; data: T } | { ok: false; response: NextResponse<ErrorResponse> }> {
  try {
    const data = (await request.json()) as T;
    return { ok: true, data };
  } catch {
    return {
      ok: false,
      response: NextResponse.json<ErrorResponse>(
        { error: "bad_request", reason: "Body không phải JSON hợp lệ" },
        { status: 400 }
      ),
    };
  }
}

// Backend không có mã lỗi riêng cho "mất kết nối" (status 0 của ApiError) — quy về 503
// database_unavailable để client dùng đúng banner "lỗi backend" đã có (US-08), không cần nhánh riêng.
export function errorResponse(error: unknown): NextResponse<ErrorResponse> {
  if (error instanceof ApiError) {
    const status = error.status === 0 ? 503 : error.status;
    const body: ErrorResponse = { error: error.code ?? "database_unavailable" };
    if (error.reason) body.reason = error.reason;
    if (error.detail) body.detail = error.detail;
    return NextResponse.json(body, { status });
  }
  return NextResponse.json<ErrorResponse>(
    { error: "database_unavailable", detail: "Lỗi không xác định ở BFF" },
    { status: 503 }
  );
}

// BFF cho PATCH /items/{id}/status (kéo thả kanban — FE-2). 409 invalid_transition được trả nguyên
// (kèm reason) để giao diện hiện đúng lý do thay vì nuốt lỗi.
import { NextRequest, NextResponse } from "next/server";
import { patchStatus } from "@/lib/api";
import {
  errorResponse,
  parseTicketId,
  readJsonBody,
  readTraceparent,
  requireUserName,
} from "@/lib/http";
import type { ErrorResponse, PatchStatusInput } from "@/lib/types";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const userName = requireUserName(request);
  if (userName instanceof NextResponse) return userName;

  const { id } = await params;
  const ticketId = parseTicketId(id);
  if (ticketId === null) {
    return NextResponse.json<ErrorResponse>(
      { error: "bad_request", reason: "id phai la so nguyen" },
      { status: 400 }
    );
  }

  const body = await readJsonBody<PatchStatusInput>(request);
  if (!body.ok) return body.response;

  try {
    const ticket = await patchStatus(ticketId, body.data, {
      userName,
      traceparent: readTraceparent(request),
    });
    return NextResponse.json(ticket);
  } catch (error) {
    return errorResponse(error);
  }
}

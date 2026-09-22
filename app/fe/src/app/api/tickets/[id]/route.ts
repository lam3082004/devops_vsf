// BFF cho PATCH /items/{id} (sửa title/description/severity/category/assignee — FE-4).
import { NextRequest, NextResponse } from "next/server";
import { patchTicket } from "@/lib/api";
import {
  errorResponse,
  parseTicketId,
  readJsonBody,
  readTraceparent,
  requireUserName,
} from "@/lib/http";
import type { ErrorResponse, PatchTicketInput } from "@/lib/types";

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

  const body = await readJsonBody<PatchTicketInput>(request);
  if (!body.ok) return body.response;

  try {
    const ticket = await patchTicket(ticketId, body.data, {
      userName,
      traceparent: readTraceparent(request),
    });
    return NextResponse.json(ticket);
  } catch (error) {
    return errorResponse(error);
  }
}

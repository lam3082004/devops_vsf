// BFF cho POST /items — client component (hộp thoại tạo ticket, FE-3) gọi route này thay vì gọi
// backend trực tiếp (trình duyệt không bao giờ được biết địa chỉ backend).
import { NextRequest, NextResponse } from "next/server";
import { createTicket } from "@/lib/api";
import { errorResponse, readJsonBody, readTraceparent, requireUserName } from "@/lib/http";
import type { CreateTicketInput } from "@/lib/types";

export async function POST(request: NextRequest) {
  const userName = requireUserName(request);
  if (userName instanceof NextResponse) return userName;

  const body = await readJsonBody<CreateTicketInput>(request);
  if (!body.ok) return body.response;

  try {
    const ticket = await createTicket(body.data, {
      userName,
      traceparent: readTraceparent(request),
    });
    return NextResponse.json(ticket, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

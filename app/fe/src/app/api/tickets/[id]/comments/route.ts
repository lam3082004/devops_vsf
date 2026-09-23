// BFF cho POST /items/{id}/comments (viết bình luận — FE-4). Không có PATCH/DELETE: bình luận không
// sửa/xoá được (US-06).
import { NextRequest, NextResponse } from "next/server";
import { addComment } from "@/lib/api";
import {
  errorResponse,
  parseTicketId,
  readJsonBody,
  readTraceparent,
  requireUserName,
} from "@/lib/http";
import type { AddCommentInput, ErrorResponse } from "@/lib/types";

export async function POST(
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

  const body = await readJsonBody<AddCommentInput>(request);
  if (!body.ok) return body.response;

  try {
    const comment = await addComment(ticketId, body.data, {
      userName,
      traceparent: readTraceparent(request),
    });
    return NextResponse.json(comment, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

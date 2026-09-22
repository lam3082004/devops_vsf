// Parse lỗi từ response BFF thành ErrorResponse (một phần) để đọc reason/detail. Dùng chung cho các
// client component trong ticket-detail/ — đều "use client" nên không import được lib/api.ts (server-
// only), phải tự đọc body lỗi bằng fetch thường (giống KanbanBoard.tsx).
import type { ErrorResponse } from "@/lib/types";

export async function parseErrorBody(res: Response): Promise<Partial<ErrorResponse>> {
  try {
    const data: unknown = await res.json();
    if (data && typeof data === "object" && "error" in data) {
      return data as ErrorResponse;
    }
  } catch {
    // Body không phải JSON hợp lệ — rơi về fallback rỗng, nơi gọi tự có message mặc định theo status.
  }
  return {};
}

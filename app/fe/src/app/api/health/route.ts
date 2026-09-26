// D17 quyết định B (notes/d17-prep.md, đóng một phần known-issues.md #16/#18). Route này
// KHÔNG phải health check nền tảng của `fe` (đó là /api/version — quyết định A, khai ở
// infra/app/app-fe.tf health_check_path) và cũng KHÔNG phải warm-up path của swap. Nó chỉ
// được CD poll (cd.yml) để chứng minh "fe thật sự nói chuyện được với be", điều mà mã SHA
// đúng của /api/version KHÔNG chứng minh được — bài học PR #46/known-issues.md #18: SHA
// khớp mà UI vẫn đóng băng banner lỗi suốt D16 vì không có gì poll việc fe gọi được be.
//
// Dùng /api/health làm health check nền tảng hay warm-up path sẽ SAI: be hỏng thì fe bị
// nền tảng coi là unhealthy và RESTART theo — restart fe không chữa được be, chỉ làm tệ
// thêm (mất luôn fe đang chạy tốt). Logic thật nằm ở src/lib/health.ts (test bằng
// health.test.mjs); route này chỉ gọi hàm đó rồi map kết quả sang mã HTTP.
import { NextResponse } from "next/server";
import { checkBackendHealth } from "@/lib/health";

// BẮT BUỘC, cùng lý do với /api/version (route.ts cạnh đây): thiếu dòng này Next sẽ
// prerender route NGAY LÚC BUILD (không đọc request nào), đóng băng kết quả — đúng bug
// #46/#18. Cổng CI (ci.yml job frontend) tự bắt được nếu quên: route phải ra `ƒ`, không `○`.
export const dynamic = "force-dynamic";

export async function GET() {
  const result = await checkBackendHealth({
    apiBaseUrl: process.env.API_BASE_URL,
    fetchImpl: fetch,
  });

  // Body CHỈ có hostname của be đã gọi, không phải URL đầy đủ — không secret, không query
  // string. status/be_status là chữ ký ổn định để CD đọc bằng jq (cd.yml).
  return NextResponse.json(
    { status: result.status, be_host: result.beHost, be_status: result.beStatus },
    { status: result.status === "ok" ? 200 : 503 }
  );
}

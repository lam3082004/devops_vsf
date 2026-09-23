// SHA của commit đã build ra image này. Cùng shape với `/version` của backend
// (app/be/Controllers/VersionController.cs → `{ "sha": "..." }`) để một script
// poll được cả hai service bằng đúng một hàm đọc.
//
// Vì sao `fe` cần route này dù `be` đã có: M10 đòi chứng minh production đổi SHA
// sau khi merge, và M2 (D18) đòi poll `/version` 1 lần/giây trong lúc swap để
// chứng minh zero-downtime. Không có route này thì `fe` chỉ chứng minh được
// "cấu hình đã trỏ sang tag mới", không chứng minh được "bản đang CHẠY đã đổi".
import { NextResponse } from "next/server";

// BẮT BUỘC. Route handler GET không đọc gì từ request sẽ được Next prerender
// NGAY LÚC BUILD, tức `process.env.GIT_SHA` bị đóng băng thành giá trị có mặt
// lúc `npm run build` — trong Dockerfile đó là stage builder, nơi ENV GIT_SHA
// chưa được đặt. Kết quả: route trả "dev" vĩnh viễn trên mọi bản deploy, và
// triệu chứng trông hệt như CD không deploy được. force-dynamic ép đọc env ở
// thời điểm request.
export const dynamic = "force-dynamic";

export function GET() {
  // "dev" khi build local không truyền --build-arg GIT_SHA — giống mặc định
  // của backend (app/be/OpsBoard.csproj, property GitSha).
  return NextResponse.json({ sha: process.env.GIT_SHA ?? "dev" });
}

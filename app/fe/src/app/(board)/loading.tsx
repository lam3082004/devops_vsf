// Next.js tự bọc Suspense quanh page.tsx bằng file loading.tsx cấp route này khi đang chờ dữ liệu
// server (4 lời gọi GET /items song song ở page.tsx). Dùng lại LoadingSkeleton chung thay vì tự vẽ.
import { LoadingSkeleton } from "@/components/states";

export default function Loading() {
  return (
    <main className="mx-auto max-w-6xl px-6 py-6">
      <LoadingSkeleton rows={4} />
    </main>
  );
}

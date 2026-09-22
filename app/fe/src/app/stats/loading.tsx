// Skeleton khi đang tải GET /stats (wire-frame.md, mục "Trạng thái giao diện phải có"). `/stats`
// không nằm trong route group `(board)` (nơi loading.tsx đã bị giới hạn phạm vi để tránh khoá status
// code 200 cho `/tickets`, xem ai-failure-log.md case #20) nên thêm loading.tsx ở đây an toàn — nó chỉ
// bọc route `/stats`, không lan sang route nào khác.
import { LoadingSkeleton } from "@/components/states";

export default function Loading() {
  return (
    <main className="mx-auto max-w-5xl px-6 py-6">
      <LoadingSkeleton rows={4} />
    </main>
  );
}

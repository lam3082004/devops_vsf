import Link from "next/link";

// 404 riêng cho /tickets/{id}: id không hợp lệ hoặc ticket không tồn tại (page.tsx tự gọi notFound()
// trong 2 trường hợp đó). Style nhất quán với components/states (border nét đứt, tiếng Việt), có
// đường quay lại danh sách thay vì trang lỗi mặc định của Next.js.
export default function TicketNotFound() {
  return (
    <main className="mx-auto max-w-5xl px-6 py-6">
      <div className="flex flex-col items-center gap-3 rounded border border-dashed border-zinc-300 px-6 py-10 text-center text-sm text-zinc-500 dark:border-zinc-700 dark:text-zinc-400">
        <p>Không tìm thấy ticket này.</p>
        <Link
          href="/tickets"
          className="rounded border border-zinc-300 px-3 py-1.5 text-zinc-700 hover:bg-zinc-100 dark:border-zinc-700 dark:text-zinc-300 dark:hover:bg-zinc-800"
        >
          Quay lại danh sách
        </Link>
      </div>
    </main>
  );
}

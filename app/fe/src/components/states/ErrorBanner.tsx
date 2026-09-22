"use client";

import { useRouter } from "next/navigation";

interface ErrorBannerProps {
  message?: string;
  onRetry?: () => void;
}

// Banner lỗi hạ tầng dùng chung (PRD US-08): không được để trắng trang, luôn có đường thử lại. Trang
// gọi component này có thể tự quyết định `onRetry` làm gì (gọi lại fetch...); nếu không truyền, mặc
// định gọi router.refresh() để server component render lại — nút "Thử lại" luôn có tác dụng.
export function ErrorBanner({
  message = "Không thể kết nối tới backend, thử lại sau.",
  onRetry,
}: ErrorBannerProps) {
  const router = useRouter();
  const handleRetry = onRetry ?? (() => router.refresh());
  return (
    <div
      role="alert"
      className="flex items-center justify-between gap-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-200"
    >
      <span>{message}</span>
      <button
        type="button"
        onClick={handleRetry}
        className="shrink-0 rounded border border-red-400 px-3 py-1 font-medium hover:bg-red-100 dark:border-red-700 dark:hover:bg-red-900"
      >
        Thử lại
      </button>
    </div>
  );
}

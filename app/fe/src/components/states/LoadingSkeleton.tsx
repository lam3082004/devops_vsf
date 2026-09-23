// Skeleton dùng chung khi đang tải (wire-frame.md, mục "Trạng thái giao diện phải có"). Component
// tĩnh, không cần "use client".
interface LoadingSkeletonProps {
  rows?: number;
  className?: string;
}

export function LoadingSkeleton({ rows = 3, className = "" }: LoadingSkeletonProps) {
  return (
    <div role="status" aria-label="Đang tải" className={`flex flex-col gap-2 ${className}`}>
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="h-4 animate-pulse rounded bg-zinc-200 dark:bg-zinc-800" />
      ))}
    </div>
  );
}

// Thanh phân bố ngang cho S6 (Thống kê) — Server Component thuần (chỉ dùng Link, không state/effect
// phía client) nên KHÔNG cần "use client". Không cài thư viện chart: chia tỉ lệ bằng div + Tailwind.
import Link from "next/link";

export interface DistributionSegment<K extends string> {
  key: K;
  label: string;
  icon?: string;
  count: number;
  href: string;
  // Class Tailwind cho màu nền segment (vd "bg-red-500"). Do nơi gọi cung cấp thay vì component này tự
  // suy ra từ `key`, vì component dùng chung cho nhiều loại dữ liệu (trạng thái, mức độ...) và không có
  // ý nghĩa gì về màu sắc của từng key cụ thể — giữ component tách khỏi domain.
  color: string;
}

interface DistributionBarProps<K extends string> {
  title: string; // "Theo trạng thái" | "Theo mức độ"
  segments: ReadonlyArray<DistributionSegment<K>>;
}

export function DistributionBar<K extends string>({
  title,
  segments,
}: DistributionBarProps<K>) {
  const total = segments.reduce((sum, segment) => sum + segment.count, 0);

  return (
    <div className="flex flex-col gap-2">
      <h2 className="text-sm font-medium text-zinc-700 dark:text-zinc-300">{title}</h2>

      <div className="flex h-4 w-full overflow-hidden rounded bg-zinc-100 dark:bg-zinc-800">
        {total === 0 ? (
          // Mọi count đều 0 (DB rỗng) — count/total sẽ là 0/0 = NaN, nên KHÔNG được chia ở nhánh này.
          // Hiện một thanh xám trung tính chiếm full width thay vì vỡ layout hay hiện "NaN%".
          <div className="h-full w-full bg-zinc-200 dark:bg-zinc-700" aria-hidden />
        ) : (
          segments
            .filter((segment) => segment.count > 0)
            .map((segment) => (
              <Link
                key={segment.key}
                href={segment.href}
                title={`${segment.label}: ${segment.count}`}
                className={`h-full ${segment.color} transition-opacity hover:opacity-80`}
                style={{ width: `${(segment.count / total) * 100}%` }}
              />
            ))
        )}
      </div>

      {/* Chú giải luôn đủ 4 mục kể cả count = 0 — bấm vào vẫn điều hướng hợp lệ, chỉ là danh sách rỗng. */}
      <ul className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-zinc-600 dark:text-zinc-400">
        {segments.map((segment) => (
          <li key={segment.key}>
            <Link
              href={segment.href}
              className="inline-flex items-center gap-1 hover:underline"
            >
              {segment.icon && <span aria-hidden>{segment.icon}</span>}
              <span>{segment.label}</span>
              <span className="font-medium text-zinc-900 dark:text-zinc-100">
                {segment.count}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

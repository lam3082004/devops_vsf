interface EmptyStateProps {
  message?: string;
}

export function EmptyState({ message = "Chưa có ticket" }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-1 rounded border border-dashed border-zinc-300 px-6 py-10 text-center text-sm text-zinc-500 dark:border-zinc-700 dark:text-zinc-400">
      <p>{message}</p>
    </div>
  );
}

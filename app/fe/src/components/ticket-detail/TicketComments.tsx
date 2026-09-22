"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useUserName } from "@/components/UserNameProvider";
import { parseErrorBody } from "@/components/ticket-detail/errors";
import { formatTime } from "@/components/ticket-detail/format";
import type { Comment } from "@/lib/types";
import { userNameHeaders } from "@/lib/userHeader";

const BODY_MAX_LENGTH = 2000;

interface TicketCommentsProps {
  ticketId: number;
  comments: Comment[];
}

// Bình luận (S5, US-06): thêm được, KHÔNG sửa/xoá — không có nút Sửa/Xoá nào ở đây dù có vẻ "tiện".
// Hiện đúng thứ tự API trả về (tăng dần theo thời gian, api-spec.md) — không đảo ngược như lịch sử.
export function TicketComments({ ticketId, comments }: TicketCommentsProps) {
  const router = useRouter();
  const { userName, requireUserName } = useUserName();
  const [body, setBody] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    // Chỉ trim để KIỂM TRA có nội dung hay không, không trim giá trị gửi đi — giữ nguyên định dạng
    // người dùng gõ (giống cách CreateTicketDialog.tsx validate title).
    if (body.trim().length < 1 || body.length > BODY_MAX_LENGTH) {
      setError(`Bình luận phải 1–${BODY_MAX_LENGTH} ký tự`);
      return; // lỗi validate → không mất nội dung đã gõ
    }

    if (!requireUserName() || !userName) return;

    setSubmitting(true);
    try {
      const res = await fetch(`/api/tickets/${ticketId}/comments`, {
        method: "POST",
        headers: userNameHeaders(userName),
        body: JSON.stringify({ body }),
      });
      if (res.ok) {
        setBody("");
        router.refresh();
        return;
      }
      const errBody = await parseErrorBody(res);
      setError(errBody.reason ?? errBody.detail ?? `Gửi bình luận thất bại (HTTP ${res.status})`);
    } catch {
      setError("Không thể kết nối tới máy chủ, thử lại.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Bình luận</h2>
      <ul className="flex flex-col gap-1.5 text-sm">
        {comments.length === 0 ? (
          <li className="text-zinc-500 dark:text-zinc-400">Chưa có bình luận</li>
        ) : (
          comments.map((comment) => (
            <li key={comment.id}>
              <span className="font-medium">{comment.author}</span>{" "}
              <span className="text-zinc-400 dark:text-zinc-500">· {formatTime(comment.created_at)}</span>{" "}
              <span className="whitespace-pre-wrap">{comment.body}</span>
            </li>
          ))
        )}
      </ul>
      <form onSubmit={handleSubmit} className="flex flex-col gap-1">
        <textarea
          value={body}
          maxLength={BODY_MAX_LENGTH}
          onChange={(event) => setBody(event.target.value)}
          rows={2}
          placeholder="Viết bình luận…"
          className="rounded border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-800"
        />
        {error && (
          <p role="alert" className="text-sm text-red-600 dark:text-red-400">
            {error}
          </p>
        )}
        <button
          type="submit"
          disabled={submitting}
          className="self-end rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-700 disabled:opacity-50 dark:bg-white dark:text-zinc-900"
        >
          Gửi
        </button>
      </form>
    </section>
  );
}

"use client";

import { useState, type FormEvent } from "react";
import { useUserName } from "@/components/UserNameProvider";
import { USER_NAME_MAX_LENGTH, isValidUserName } from "@/lib/user-name";

// Hộp nhập tên (wire-frame S1) — lần đầu vào hoặc bấm 👤 để đổi tên. Render trong layout gốc nên có
// mặt ở mọi trang; tự ẩn khi context nói hộp đang đóng.
export function NameGate() {
  const { isGateOpen, userName, setUserName, closeGate } = useUserName();
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);

  if (!isGateOpen) return null;

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!isValidUserName(draft)) {
      setError(`Tên phải 1–${USER_NAME_MAX_LENGTH} ký tự`);
      return;
    }
    setUserName(draft);
    setDraft("");
    setError(null);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div className="w-full max-w-sm rounded-lg border border-zinc-200 bg-white p-6 shadow-lg dark:border-zinc-800 dark:bg-zinc-900">
        <h2 className="text-lg font-semibold">Bạn là ai?</h2>
        <form onSubmit={handleSubmit} className="mt-4 flex flex-col gap-2">
          <label htmlFor="user-name-input" className="text-sm text-zinc-600 dark:text-zinc-400">
            Tên (1–{USER_NAME_MAX_LENGTH} ký tự)
          </label>
          <input
            id="user-name-input"
            autoFocus
            value={draft}
            maxLength={USER_NAME_MAX_LENGTH}
            onChange={(event) => setDraft(event.target.value)}
            className="rounded border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-800"
            placeholder="Ví dụ: Lâm"
          />
          {error && <p className="text-sm text-red-600 dark:text-red-400">{error}</p>}
          <div className="mt-2 flex justify-end gap-2">
            {userName && (
              <button
                type="button"
                onClick={closeGate}
                className="rounded px-3 py-2 text-sm text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-800"
              >
                Huỷ
              </button>
            )}
            <button
              type="submit"
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-700 dark:bg-white dark:text-zinc-900"
            >
              Vào
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

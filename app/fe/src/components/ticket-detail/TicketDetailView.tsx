"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useUserName } from "@/components/UserNameProvider";
import { parseErrorBody } from "@/components/ticket-detail/errors";
import { TicketComments } from "@/components/ticket-detail/TicketComments";
import { TicketMainPanel } from "@/components/ticket-detail/TicketMainPanel";
import { TicketSidePanel } from "@/components/ticket-detail/TicketSidePanel";
import type { TicketEditDraft, TicketFieldErrors } from "@/components/ticket-detail/types";
import type { Activity, Comment, PatchTicketInput, Ticket } from "@/lib/types";
import { userNameHeaders } from "@/lib/userHeader";

const TITLE_MAX_LENGTH = 200;
const DESCRIPTION_MAX_LENGTH = 5000;
const ASSIGNEE_MAX_LENGTH = 50;

interface TicketDetailViewProps {
  ticket: Ticket;
  activities: Activity[];
  comments: Comment[];
}

function draftFromTicket(ticket: Ticket): TicketEditDraft {
  return {
    title: ticket.title,
    description: ticket.description ?? "",
    severity: ticket.severity,
    category: ticket.category,
    assignee: ticket.assignee ?? "",
  };
}

function validateDraft(draft: TicketEditDraft): TicketFieldErrors {
  const errors: TicketFieldErrors = {};
  const title = draft.title.trim();
  if (title.length < 1 || title.length > TITLE_MAX_LENGTH) {
    errors.title = `Tiêu đề phải 1–${TITLE_MAX_LENGTH} ký tự`;
  }
  if (draft.description.length > DESCRIPTION_MAX_LENGTH) {
    errors.description = `Mô tả tối đa ${DESCRIPTION_MAX_LENGTH} ký tự`;
  }
  if (draft.assignee.length > ASSIGNEE_MAX_LENGTH) {
    errors.assignee = `Người xử lý tối đa ${ASSIGNEE_MAX_LENGTH} ký tự`;
  }
  return errors;
}

// So sánh draft với ticket gốc để CHỈ đưa vào patch field thật sự đổi (api-spec.md: field vắng mặt =
// không đổi; gửi cả object mỗi lần sẽ ghi đè trường người khác vừa sửa — xem docs/docs_app/plan/fe.md
// mục FE-4). Không gán field nào coi như bỏ qua — JSON.stringify tự bỏ key không tồn tại trên object,
// đúng như PatchTicketInput mong đợi. description/assignee đổi thành rỗng phải gửi null tường minh
// (xoá), không phải bỏ qua field — status thì KHÔNG BAO GIỜ có mặt ở patch này (đi qua endpoint khác).
function buildPatch(ticket: Ticket, draft: TicketEditDraft): PatchTicketInput {
  const patch: PatchTicketInput = {};

  const trimmedTitle = draft.title.trim();
  if (trimmedTitle !== ticket.title) patch.title = trimmedTitle;

  const originalDescription = ticket.description ?? "";
  if (draft.description !== originalDescription) {
    patch.description = draft.description === "" ? null : draft.description;
  }

  if (draft.severity !== ticket.severity) patch.severity = draft.severity;
  if (draft.category !== ticket.category) patch.category = draft.category;

  const originalAssignee = ticket.assignee ?? "";
  if (draft.assignee !== originalAssignee) {
    patch.assignee = draft.assignee === "" ? null : draft.assignee;
  }

  return patch;
}

// Orchestrator trang chi tiết ticket (S5, FE-4). page.tsx (server) gọi 2 API riêng rồi giao dữ liệu
// xuống đây; component này lo layout 2 cột + trạng thái "đang sửa" của title/description/severity/
// category/assignee (một lần PATCH /items/{id}). Đổi trạng thái (TicketStatusControl) và bình luận
// (TicketComments) có logic fetch riêng, độc lập hoàn toàn với chế độ sửa này.
export function TicketDetailView({ ticket, activities, comments }: TicketDetailViewProps) {
  const router = useRouter();
  const { userName, requireUserName } = useUserName();

  const [isEditing, setIsEditing] = useState(false);
  const [draft, setDraft] = useState<TicketEditDraft | null>(null);
  // Snapshot riêng của ticket tại thời điểm bấm "Sửa" — KHÔNG dùng prop `ticket` sống ở handleSave, vì
  // TicketStatusControl/TicketComments có thể gọi router.refresh() độc lập trong lúc form đang mở, làm
  // prop `ticket` trôi sang giá trị mới; buildPatch phải diff với baseline cùng thời điểm với draft.
  const [originalTicket, setOriginalTicket] = useState<Ticket | null>(null);
  const [fieldErrors, setFieldErrors] = useState<TicketFieldErrors>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  function startEdit() {
    setOriginalTicket(ticket);
    setDraft(draftFromTicket(ticket));
    setFieldErrors({});
    setFormError(null);
    setIsEditing(true);
  }

  function cancelEdit() {
    setIsEditing(false);
    setDraft(null);
    setOriginalTicket(null);
    setFieldErrors({});
    setFormError(null);
  }

  function updateDraft(patch: Partial<TicketEditDraft>) {
    setDraft((prev) => (prev ? { ...prev, ...patch } : prev));
  }

  async function handleSave() {
    if (!draft || !originalTicket) return;
    setFormError(null);

    const errors = validateDraft(draft);
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) return; // lỗi validate → giữ nguyên dữ liệu đã nhập, không gửi

    if (!requireUserName() || !userName) return;

    const patch = buildPatch(originalTicket, draft);
    if (Object.keys(patch).length === 0) {
      // Không có field nào thật sự đổi — thoát sửa luôn, khỏi gọi PATCH với body rỗng.
      cancelEdit();
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`/api/tickets/${ticket.id}`, {
        method: "PATCH",
        headers: userNameHeaders(userName),
        body: JSON.stringify(patch),
      });
      if (res.ok) {
        setIsEditing(false);
        setDraft(null);
        setOriginalTicket(null);
        router.refresh(); // tải lại ticket + lịch sử mới nhất từ server component
        return;
      }
      const body = await parseErrorBody(res);
      setFormError(body.reason ?? body.detail ?? `Lưu thất bại (HTTP ${res.status})`);
      // Thất bại: KHÔNG reset draft — giữ nguyên dữ liệu đã nhập trong form (giống US-02).
    } catch {
      setFormError("Không thể kết nối tới máy chủ, thử lại.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
      <div className="flex flex-col gap-6">
        <TicketMainPanel
          ticket={ticket}
          isEditing={isEditing}
          draft={draft}
          fieldErrors={fieldErrors}
          formError={formError}
          submitting={submitting}
          onDraftChange={updateDraft}
          onStartEdit={startEdit}
          onCancelEdit={cancelEdit}
          onSave={handleSave}
        />
        <TicketComments ticketId={ticket.id} comments={comments} />
      </div>
      <TicketSidePanel
        ticket={ticket}
        activities={activities}
        isEditing={isEditing}
        draft={draft}
        fieldErrors={fieldErrors}
        submitting={submitting}
        onDraftChange={updateDraft}
      />
    </div>
  );
}

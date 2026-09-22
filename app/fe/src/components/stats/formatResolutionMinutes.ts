// Định dạng "thời gian xử lý trung bình" cho ô số S6 (wire-frame.md). `null` KHÁC `0`: 0 nghĩa là
// "trung bình 0 phút" — có thật, ticket được resolve gần như ngay lập tức. `null` nghĩa là chưa có
// ticket nào ở trạng thái resolved nên chưa có gì để tính trung bình; hiện "0 phút" trong trường hợp
// này sẽ khiến người đọc hiểu nhầm là hệ thống xử lý cực nhanh, nên phải nói rõ "chưa có dữ liệu".
export function formatResolutionMinutes(minutes: number | null): string {
  if (minutes === null) return "chưa có dữ liệu";
  if (minutes < 60) return `${minutes} phút`;

  // Backend luôn trả số phút nguyên đã làm tròn (TicketRepository.cs) nên không cần xử lý thập phân.
  const hours = Math.floor(minutes / 60);
  const remainderMinutes = minutes % 60;
  return `${hours} giờ ${remainderMinutes} phút`;
}

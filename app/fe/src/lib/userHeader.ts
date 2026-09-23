// Header dùng chung cho request ghi cần định danh người dùng. Percent-encode MỘT LẦN DUY NHẤT ở đây —
// bug gốc là quên encode ở một vài chỗ gọi khiến tên tiếng Việt phá HTTP header (xem ai-failure-log.md).
// Header HTTP không mang được ký tự ngoài ASCII đáng tin cậy — trình duyệt tự mã hoá theo ISO-8859-1
// hoặc ném lỗi ngay tại fetch() — nên percent-encode trước khi đặt header, backend decode lại
// (UserNameFilter.cs).
export function userNameHeaders(userName: string): Record<string, string> {
  return {
    "Content-Type": "application/json",
    "X-User-Name": encodeURIComponent(userName),
  };
}

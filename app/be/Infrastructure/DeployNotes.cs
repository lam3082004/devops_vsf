// D14 — FILE RÁC CÓ CHỦ Ý, dùng để chứng minh gitleaks chặn được secret (M9).
// Chuỗi dưới đây là token BỊA, chưa bao giờ tồn tại và không cấp quyền vào đâu cả.
// PR chứa file này sẽ bị đóng và xoá nhánh, không bao giờ merge vào main.
namespace OpsBoard.Infrastructure;

internal static class DeployNotes
{
    private const string GithubToken = "ghp_S7kQ2mVxL9pRtYwZ4bNcH1jF6dG8aE3uK0oI";
}

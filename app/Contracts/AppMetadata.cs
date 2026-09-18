namespace NodeRegistry.Contracts;

/// SHA của commit, nhúng lúc build (xem NodeRegistry.csproj, Target EmbedGitSha)
/// — bọc lại thành một object đăng ký DI thay vì đọc hằng số BuildInfo.GitSha
/// thẳng trong controller, để controller không phụ thuộc trực tiếp vào code
/// sinh tự động.
public sealed class AppMetadata
{
    public string GitSha { get; }

    public AppMetadata(string gitSha) => GitSha = gitSha;
}

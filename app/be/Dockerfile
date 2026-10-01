# Base image khai báo bằng ARG để CI/registry mirror thay được mà không sửa file.
# Ghim tag cụ thể, không bao giờ dùng :latest — build phải tái lập được.
ARG SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0
# "chiseled": biến thể tối giản của Microsoft — không shell, không apt, không
# package quản lý; container chạy sẵn non-root (uid 1654 = $APP_UID, user "app";
# kiểm 01/10 bằng `docker image inspect` → Config.User = 1654).
# Khác bản Rust (musl + scratch, static binary): app ở đây publish
# framework-dependent nên vẫn cần runtime ASP.NET Core bên trong image, không
# thể xuống tới scratch — 0 CVE không chắc đạt được, phải đo lại bằng Trivy.
ARG RUNTIME_IMAGE=mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled

# ---------- Stage 1: build ----------
FROM ${SDK_IMAGE} AS builder
WORKDIR /src

# Build một layer restore riêng: chỉ copy file project trước, sửa code sau
# này không phải tải lại NuGet — tương đương cache Cargo.toml/Cargo.lock.
COPY OpsBoard.csproj ./
RUN dotnet restore OpsBoard.csproj

COPY . .

# SHA của commit: docker build --build-arg GIT_SHA=$(git rev-parse --short HEAD)
# Không truyền thì /version trả "dev" (mặc định trong .csproj).
ARG GIT_SHA
RUN dotnet publish OpsBoard.csproj -c Release -o /app/publish \
    -p:GitSha=${GIT_SHA} --no-self-contained

# ---------- Stage 2: runtime ----------
FROM ${RUNTIME_IMAGE}
WORKDIR /app
COPY --from=builder /app/publish .

# Image chiseled đã chạy sẵn non-root (uid 1654), nhưng vẫn khai USER tường minh: công cụ quét
# tĩnh (Trivy DS-0002, Semgrep missing-user-entrypoint) không đọc được user của base image, và
# Dockerfile tự nói rõ ý định thì đổi base image sau này không lặng lẽ thành root.
USER $APP_UID
EXPOSE 8080

# Dạng exec: process dotnet là PID 1, nhận thẳng SIGTERM từ docker stop và
# App Service, nhờ đó graceful shutdown (Program.cs) chạy được. Bọc qua shell
# là mất tín hiệu — nhưng image chiseled còn không có shell để bọc qua.
ENTRYPOINT ["dotnet", "OpsBoard.dll"]

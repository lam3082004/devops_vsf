# Base image khai báo bằng ARG để CI/registry mirror có thể thay mà không sửa file.
# Ghim tag cụ thể, không bao giờ dùng :latest — build phải tái lập được.
ARG RUST_IMAGE=rust:1.95-slim
ARG RUNTIME_IMAGE=scratch
# Build tĩnh với musl: binary không phụ thuộc glibc/openssl của hệ điều hành,
# nên image runtime không còn package nào để Trivy tìm ra CVE (M9).
ARG RUST_TARGET=x86_64-unknown-linux-musl

# ---------- Stage 1: build ----------
FROM ${RUST_IMAGE} AS builder
ARG RUST_TARGET

RUN apt-get update \
    && apt-get install -y --no-install-recommends musl-tools pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN rustup target add ${RUST_TARGET}

WORKDIR /build

# Build một binary rỗng trước để Docker cache layer dependencies: sửa src/ sau này
# không phải biên dịch lại axum/tokio/sqlx. Build Rust rất chậm và CI (D14) chạy mỗi PR.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --target ${RUST_TARGET} \
    && rm -rf src target/${RUST_TARGET}/release/node-registry \
              target/${RUST_TARGET}/release/deps/node_registry*

COPY build.rs ./
COPY src ./src

# SHA của commit: docker build --build-arg GIT_SHA=$(git rev-parse --short HEAD)
# Không truyền thì /version trả "dev" — CD ở D16 luôn phải truyền.
ARG GIT_SHA
ENV GIT_SHA=${GIT_SHA}

RUN cargo build --release --target ${RUST_TARGET} \
    && strip target/${RUST_TARGET}/release/node-registry \
    && cp target/${RUST_TARGET}/release/node-registry /node-registry

# ---------- Stage 2: runtime ----------
# scratch: không shell, không package manager, không package OS nào.
FROM ${RUNTIME_IMAGE}

COPY --from=builder /node-registry /app/node-registry

# scratch không có /etc/passwd nên chỉ định uid dạng số (trùng uid nonroot của distroless).
USER 65532:65532

EXPOSE 8080

# Dạng exec: binary là PID 1 → nhận thẳng SIGTERM từ docker stop và App Service,
# nhờ đó graceful shutdown chạy. Bọc qua shell là mất tín hiệu.
ENTRYPOINT ["/app/node-registry"]

mod config;
mod db;
mod http;
mod nodes;

use std::sync::Arc;

use config::Config;
use http::AppState;

/// SHA của commit, nhúng lúc build qua biến môi trường GIT_SHA.
/// Build local không truyền gì thì là "dev".
pub const GIT_SHA: &str = match option_env!("GIT_SHA") {
    Some(sha) => sha,
    None => "dev",
};

fn init_logging() {
    tracing_subscriber::fmt()
        .json()
        .flatten_event(true)
        .with_current_span(false)
        .with_span_list(false)
        .with_target(false)
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();
}

#[tokio::main]
async fn main() {
    init_logging();

    let config = match Config::from_env() {
        Ok(config) => config,
        Err(err) => {
            // Chỉ log tên biến và lý do — không bao giờ log giá trị.
            // Không đặt trường tên "level": nó trùng key mà subscriber đã sinh.
            tracing::error!(event = "config_error", error = %err, "loi cau hinh, dung app");
            std::process::exit(1);
        }
    };

    tracing::info!(
        event = "startup",
        sha = GIT_SHA,
        port = config.port,
        db_host = %config.db_host,
        db_name = %config.db_name,
        db_tls = config.db_tls,
        load_max_seconds = config.load_max_seconds,
        "app khoi dong"
    );

    let port = config.port;
    let pool = db::build_pool(&config);

    // Tạo bảng nếu chưa có. DB chưa sẵn sàng thì chỉ cảnh báo: app vẫn chạy,
    // /health trả 503 cho tới khi DB lên.
    match db::ensure_schema(&pool).await {
        Ok(()) => tracing::info!(event = "schema_ready", "bang nodes san sang"),
        Err(err) => {
            tracing::warn!(event = "schema_failed", error = %err, "chua tao duoc bang, se thu lai khi co request")
        }
    }

    let state = AppState {
        config: Arc::new(config),
        pool,
    };

    let listener = match tokio::net::TcpListener::bind(("0.0.0.0", port)).await {
        Ok(listener) => listener,
        Err(err) => {
            tracing::error!(event = "bind_failed", port = port, error = %err, "khong mo duoc cong");
            std::process::exit(1);
        }
    };

    tracing::info!(event = "listening", port = port, "san sang nhan request");

    let pool_for_shutdown = state.pool.clone();

    let server =
        axum::serve(listener, http::router(state)).with_graceful_shutdown(shutdown_signal());

    if let Err(err) = server.await {
        tracing::error!(event = "server_error", error = %err, "server dung bat thuong");
        std::process::exit(1);
    }

    // Tới đây: đã ngừng nhận kết nối mới và các request đang dở đã xong.
    pool_for_shutdown.close().await;
    tracing::info!(event = "shutdown_complete", "dong pool DB, thoat sach");
}

/// Chờ SIGTERM (App Service/Docker gửi khi dừng container) hoặc SIGINT (Ctrl+C).
/// Không xử lý tín hiệu = container bị kill cứng sau thời gian chờ, request đang
/// dở bị cắt giữa chừng — đúng nguyên nhân gây gián đoạn khi swap ở D2.
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("khong dang ky duoc handler cho Ctrl+C");
    };

    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("khong dang ky duoc handler cho SIGTERM")
            .recv()
            .await;
    };

    let signal = tokio::select! {
        _ = ctrl_c => "SIGINT",
        _ = terminate => "SIGTERM",
    };

    tracing::info!(
        event = "shutdown_started",
        signal = signal,
        "nhan tin hieu dung, ngung nhan request moi va cho request dang do"
    );
}

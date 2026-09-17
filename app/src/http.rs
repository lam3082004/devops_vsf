use std::sync::Arc;
use std::time::Instant;

use axum::{
    Json, Router,
    extract::{Query, Request, State},
    http::StatusCode,
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use serde::Deserialize;
use serde_json::json;
use sqlx::MySqlPool;

use crate::GIT_SHA;
use crate::config::Config;
use crate::nodes::RegisterNode;
use crate::{db, nodes};

#[derive(Clone)]
pub struct AppState {
    pub config: Arc<Config>,
    pub pool: MySqlPool,
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/items", get(list_items).post(register_item))
        .route("/version", get(version))
        .route("/load", get(load))
        .route("/boom", get(boom))
        .fallback(not_found)
        .layer(middleware::from_fn(log_requests))
        .with_state(state)
}

/// Một dòng JSON cho mỗi request: method, path, status, thời gian, request_id.
async fn log_requests(request: Request, next: Next) -> Response {
    let method = request.method().to_string();
    let path = request.uri().path().to_string();
    let request_id = uuid::Uuid::new_v4().to_string();
    let started = Instant::now();

    let response = next.run(request).await;

    tracing::info!(
        event = "request",
        method = %method,
        path = %path,
        status = response.status().as_u16(),
        duration_ms = started.elapsed().as_millis() as u64,
        request_id = %request_id,
        "request"
    );

    response
}

/// Sẵn sàng nhận traffic hay chưa: có ping được DB không.
/// 503 khi DB lỗi để warm-up của slot swap từ chối bản mới (D17).
async fn health(State(state): State<AppState>) -> Response {
    match db::ping(&state.pool).await {
        Ok(()) => (StatusCode::OK, Json(json!({ "status": "ok", "db": "ok" }))).into_response(),
        Err(err) => {
            tracing::warn!(event = "health_degraded", error = %err, "khong ping duoc DB");
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({ "status": "degraded", "db": "error" })),
            )
                .into_response()
        }
    }
}

async fn list_items(State(state): State<AppState>) -> Response {
    match nodes::list(&state.pool).await {
        Ok(items) => (StatusCode::OK, Json(json!(items))).into_response(),
        Err(err) => db_error("list_nodes", err),
    }
}

async fn register_item(
    State(state): State<AppState>,
    Json(payload): Json<RegisterNode>,
) -> Response {
    let (name, address, role) = match payload.validated() {
        Ok(values) => values,
        Err(err) => return bad_request(err.reason()),
    };

    match nodes::register(&state.pool, &name, address.as_deref(), &role).await {
        Ok(node) => (StatusCode::CREATED, Json(json!(node))).into_response(),
        Err(err) => db_error("register_node", err),
    }
}

/// Lỗi DB: log chi tiết cho người vận hành, trả về client thông báo chung.
fn db_error(event: &'static str, err: sqlx::Error) -> Response {
    tracing::error!(event = event, error = %err, "thao tac DB that bai");
    (
        StatusCode::SERVICE_UNAVAILABLE,
        Json(json!({ "error": "database_unavailable" })),
    )
        .into_response()
}

async fn version() -> impl IntoResponse {
    Json(json!({ "sha": GIT_SHA }))
}

#[derive(Debug, Deserialize)]
struct LoadParams {
    seconds: Option<String>,
}

/// Đốt CPU đúng `seconds` giây để chứng minh autoscale (M7).
/// Chạy trong spawn_blocking: vòng lặp bận trong task async sẽ chặn cả runtime,
/// làm /health không phản hồi và instance bị coi là hỏng.
async fn load(State(state): State<AppState>, Query(params): Query<LoadParams>) -> Response {
    let max = state.config.load_max_seconds;

    let seconds = match params.seconds.as_deref() {
        None => return bad_request("thieu tham so 'seconds'"),
        Some(raw) => match raw.trim().parse::<u64>() {
            Err(_) => return bad_request("'seconds' phai la so nguyen duong"),
            Ok(value) if value < 1 || value > max => {
                return bad_request("'seconds' ngoai khoang cho phep");
            }
            Ok(value) => value,
        },
    };

    let burned = tokio::task::spawn_blocking(move || {
        let deadline = Instant::now() + std::time::Duration::from_secs(seconds);
        let mut iterations: u64 = 0;
        while Instant::now() < deadline {
            iterations = iterations.wrapping_add(1);
            std::hint::black_box(iterations);
        }
        iterations
    })
    .await;

    match burned {
        Ok(iterations) => (
            StatusCode::OK,
            Json(json!({ "burned_seconds": seconds, "iterations": iterations })),
        )
            .into_response(),
        Err(err) => {
            tracing::error!(event = "load_failed", error = %err, "task dot CPU that bai");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": "load_failed" })),
            )
                .into_response()
        }
    }
}

/// Lỗi cố ý để chứng minh alert 5xx (M11). Ghi log level error kèm chi tiết
/// trong MỘT trường JSON, và tiến trình phải sống tiếp.
async fn boom() -> Response {
    let detail = "loi co y tu /boom de kiem thu alert va logging";
    tracing::error!(
        event = "boom",
        error = "intentional_failure",
        detail = detail,
        "endpoint /boom nem loi co y"
    );
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({ "error": "boom", "detail": detail })),
    )
        .into_response()
}

async fn not_found() -> Response {
    (StatusCode::NOT_FOUND, Json(json!({ "error": "not_found" }))).into_response()
}

fn bad_request(reason: &str) -> Response {
    (
        StatusCode::BAD_REQUEST,
        Json(json!({ "error": "bad_request", "reason": reason })),
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request as HttpRequest;
    use tower::ServiceExt;

    fn test_state() -> AppState {
        let config = Config {
            port: 8080,
            db_host: "127.0.0.1".to_string(),
            db_port: 3306,
            db_name: "test".to_string(),
            db_user: "test".to_string(),
            db_password: "test".to_string(),
            db_tls: false,
            load_max_seconds: 60,
        };
        let pool = crate::db::build_pool(&config);
        AppState {
            config: Arc::new(config),
            pool,
        }
    }

    async fn get(path: &str) -> (StatusCode, String) {
        let response = router(test_state())
            .oneshot(
                HttpRequest::builder()
                    .uri(path)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = response.status();
        let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        (status, String::from_utf8(bytes.to_vec()).unwrap())
    }

    #[tokio::test]
    async fn version_tra_ve_sha_duoc_nhung() {
        let (status, body) = get("/version").await;
        assert_eq!(status, StatusCode::OK);
        assert!(body.contains(GIT_SHA));
    }

    #[tokio::test]
    async fn load_tu_choi_tham_so_sai() {
        for path in [
            "/load",
            "/load?seconds=abc",
            "/load?seconds=0",
            "/load?seconds=61",
        ] {
            let (status, body) = get(path).await;
            assert_eq!(status, StatusCode::BAD_REQUEST, "path {path} phai tra 400");
            assert!(body.contains("bad_request"));
        }
    }

    #[tokio::test]
    async fn boom_tra_500_va_khong_lam_chet_app() {
        let (status, _) = get("/boom").await;
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        let (status_sau, _) = get("/version").await;
        assert_eq!(status_sau, StatusCode::OK);
    }

    #[tokio::test]
    async fn path_la_tra_404_json() {
        let (status, body) = get("/khong-co-that").await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert!(body.contains("not_found"));
    }
}

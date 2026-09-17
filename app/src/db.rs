use std::time::Duration;

use sqlx::mysql::{MySqlConnectOptions, MySqlPoolOptions, MySqlSslMode};
use sqlx::{MySqlPool, Row};

use crate::config::Config;

/// Thời gian tối đa cho một lần ping trong /health. Ngắn, vì health check của
/// App Service có timeout riêng và không được để nó treo.
const HEALTH_TIMEOUT: Duration = Duration::from_secs(1);

/// Tạo pool ở chế độ lazy: app **khởi động được ngay cả khi DB chưa sẵn sàng**,
/// và /health sẽ trả 503 cho tới khi kết nối được. Nếu tạo pool eager, app sẽ
/// chết lúc khởi động và swap ở D17 không có gì để warm-up.
pub fn build_pool(config: &Config) -> MySqlPool {
    let ssl_mode = if config.db_tls {
        MySqlSslMode::Required
    } else {
        MySqlSslMode::Disabled
    };

    let options = MySqlConnectOptions::new()
        .host(&config.db_host)
        .port(config.db_port)
        .username(&config.db_user)
        .password(&config.db_password)
        .database(&config.db_name)
        .ssl_mode(ssl_mode);

    MySqlPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(5))
        .connect_lazy_with(options)
}

/// Tạo bảng nếu chưa có. Chạy được nhiều lần (idempotent) nên khởi động lại
/// app bao nhiêu lần cũng không lỗi.
pub async fn ensure_schema(pool: &MySqlPool) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS nodes (
            id            BIGINT       NOT NULL AUTO_INCREMENT,
            name          VARCHAR(200) NOT NULL,
            address       VARCHAR(100) NULL,
            role          VARCHAR(50)  NOT NULL DEFAULT 'worker',
            last_seen_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uk_nodes_name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        "#,
    )
    .execute(pool)
    .await?;
    Ok(())
}

/// Ping DB cho /health. Trả Err khi DB không phản hồi trong HEALTH_TIMEOUT.
pub async fn ping(pool: &MySqlPool) -> Result<(), String> {
    match tokio::time::timeout(HEALTH_TIMEOUT, sqlx::query("SELECT 1").fetch_one(pool)).await {
        Ok(Ok(row)) => {
            let _: i32 = row.try_get(0).map_err(|err| err.to_string())?;
            Ok(())
        }
        Ok(Err(err)) => Err(err.to_string()),
        Err(_) => Err(format!("het thoi gian cho sau {HEALTH_TIMEOUT:?}")),
    }
}

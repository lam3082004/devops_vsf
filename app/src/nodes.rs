use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{MySqlPool, Row};

/// Số bản ghi tối đa trả về, để một node lỡ spam không kéo cả bảng ra.
const LIST_LIMIT: i64 = 100;

pub const NAME_MAX: usize = 200;
pub const ROLE_MAX: usize = 50;
pub const ADDRESS_MAX: usize = 100;

#[derive(Debug, Serialize)]
pub struct Node {
    pub id: i64,
    pub name: String,
    pub address: Option<String>,
    pub role: String,
    pub last_seen_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct RegisterNode {
    pub name: String,
    pub address: Option<String>,
    pub role: Option<String>,
}

#[derive(Debug)]
pub enum ValidationError {
    NameEmpty,
    NameTooLong,
    AddressTooLong,
    RoleTooLong,
}

impl ValidationError {
    pub fn reason(&self) -> &'static str {
        match self {
            ValidationError::NameEmpty => "'name' khong duoc rong",
            ValidationError::NameTooLong => "'name' toi da 200 ky tu",
            ValidationError::AddressTooLong => "'address' toi da 100 ky tu",
            ValidationError::RoleTooLong => "'role' toi da 50 ky tu",
        }
    }
}

impl RegisterNode {
    /// Chuẩn hoá và kiểm tra dữ liệu vào trước khi chạm tới DB.
    pub fn validated(self) -> Result<(String, Option<String>, String), ValidationError> {
        let name = self.name.trim().to_string();
        if name.is_empty() {
            return Err(ValidationError::NameEmpty);
        }
        if name.chars().count() > NAME_MAX {
            return Err(ValidationError::NameTooLong);
        }

        let address = match self.address {
            Some(value) if !value.trim().is_empty() => {
                let value = value.trim().to_string();
                if value.chars().count() > ADDRESS_MAX {
                    return Err(ValidationError::AddressTooLong);
                }
                Some(value)
            }
            _ => None,
        };

        let role = match self.role {
            Some(value) if !value.trim().is_empty() => value.trim().to_string(),
            _ => "worker".to_string(),
        };
        if role.chars().count() > ROLE_MAX {
            return Err(ValidationError::RoleTooLong);
        }

        Ok((name, address, role))
    }
}

/// Đăng ký node. Trùng `name` thì cập nhật lần thấy cuối thay vì báo lỗi —
/// đúng ngữ nghĩa của một registry: node tự khai báo lại mỗi lần khởi động.
pub async fn register(
    pool: &MySqlPool,
    name: &str,
    address: Option<&str>,
    role: &str,
) -> Result<Node, sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO nodes (name, address, role)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            address = VALUES(address),
            role = VALUES(role),
            last_seen_at = CURRENT_TIMESTAMP
        "#,
    )
    .bind(name)
    .bind(address)
    .bind(role)
    .execute(pool)
    .await?;

    get_by_name(pool, name).await
}

pub async fn get_by_name(pool: &MySqlPool, name: &str) -> Result<Node, sqlx::Error> {
    let row = sqlx::query(
        "SELECT id, name, address, role, last_seen_at FROM nodes WHERE name = ? LIMIT 1",
    )
    .bind(name)
    .fetch_one(pool)
    .await?;

    Ok(Node {
        id: row.try_get("id")?,
        name: row.try_get("name")?,
        address: row.try_get("address")?,
        role: row.try_get("role")?,
        last_seen_at: row.try_get("last_seen_at")?,
    })
}

pub async fn list(pool: &MySqlPool) -> Result<Vec<Node>, sqlx::Error> {
    let rows = sqlx::query(
        "SELECT id, name, address, role, last_seen_at FROM nodes \
         ORDER BY last_seen_at DESC, id DESC LIMIT ?",
    )
    .bind(LIST_LIMIT)
    .fetch_all(pool)
    .await?;

    rows.into_iter()
        .map(|row| {
            Ok(Node {
                id: row.try_get("id")?,
                name: row.try_get("name")?,
                address: row.try_get("address")?,
                role: row.try_get("role")?,
                last_seen_at: row.try_get("last_seen_at")?,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn payload(name: &str) -> RegisterNode {
        RegisterNode {
            name: name.to_string(),
            address: None,
            role: None,
        }
    }

    #[test]
    fn name_rong_bi_tu_choi() {
        assert!(matches!(
            payload("   ").validated(),
            Err(ValidationError::NameEmpty)
        ));
    }

    #[test]
    fn name_qua_dai_bi_tu_choi() {
        let long = "a".repeat(NAME_MAX + 1);
        assert!(matches!(
            payload(&long).validated(),
            Err(ValidationError::NameTooLong)
        ));
    }

    #[test]
    fn role_mac_dinh_la_worker() {
        let (name, address, role) = payload(" node-01 ").validated().unwrap();
        assert_eq!(name, "node-01");
        assert_eq!(address, None);
        assert_eq!(role, "worker");
    }
}

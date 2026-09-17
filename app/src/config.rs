use std::env;
use std::fmt;

/// Lỗi cấu hình. Chỉ mang **tên biến**, không bao giờ mang giá trị,
/// để thông báo lỗi không làm lộ mật khẩu ra log.
#[derive(Debug)]
pub enum ConfigError {
    /// Biến bắt buộc không có hoặc rỗng.
    Missing(&'static str),
    /// Biến có giá trị nhưng không dùng được (không parse được, ngoài khoảng...).
    Invalid {
        var: &'static str,
        reason: &'static str,
    },
    /// Giá trị vẫn là tham chiếu Key Vault chưa được nền tảng resolve.
    UnresolvedKeyVault(&'static str),
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::Missing(var) => {
                write!(f, "bien moi truong bat buoc '{var}' bi thieu hoac rong")
            }
            ConfigError::Invalid { var, reason } => {
                write!(f, "bien moi truong '{var}' khong hop le: {reason}")
            }
            ConfigError::UnresolvedKeyVault(var) => write!(
                f,
                "bien moi truong '{var}' van la tham chieu Key Vault chua resolve \
                 (@Microsoft.KeyVault...): kiem tra quyen cua managed identity tren Key Vault"
            ),
        }
    }
}

impl std::error::Error for ConfigError {}

#[derive(Debug, Clone)]
pub struct Config {
    pub port: u16,
    pub db_host: String,
    pub db_port: u16,
    pub db_name: String,
    pub db_user: String,
    pub db_password: String,
    pub db_tls: bool,
    pub load_max_seconds: u64,
}

/// Tiền tố mà App Service để nguyên trong biến môi trường khi nó **không**
/// resolve được tham chiếu Key Vault (mất quyền, sai URI, secret bị xoá...).
const KEY_VAULT_PREFIX: &str = "@Microsoft.KeyVault(";

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        let db_password = required("DB_PASSWORD")?;
        if db_password.starts_with(KEY_VAULT_PREFIX) {
            return Err(ConfigError::UnresolvedKeyVault("DB_PASSWORD"));
        }

        let load_max_seconds = number::<u64>("LOAD_MAX_SECONDS", 60)?;
        if !(1..=300).contains(&load_max_seconds) {
            return Err(ConfigError::Invalid {
                var: "LOAD_MAX_SECONDS",
                reason: "phai nam trong khoang 1..=300",
            });
        }

        Ok(Config {
            port: number::<u16>("PORT", 8080)?,
            db_host: required("DB_HOST")?,
            db_port: number::<u16>("DB_PORT", 3306)?,
            db_name: required("DB_NAME")?,
            db_user: required("DB_USER")?,
            db_password,
            db_tls: boolean("DB_TLS", true)?,
            load_max_seconds,
        })
    }
}

fn required(var: &'static str) -> Result<String, ConfigError> {
    match env::var(var) {
        Ok(value) if !value.trim().is_empty() => Ok(value),
        _ => Err(ConfigError::Missing(var)),
    }
}

fn number<T: std::str::FromStr>(var: &'static str, default: T) -> Result<T, ConfigError> {
    match env::var(var) {
        Err(_) => Ok(default),
        Ok(value) if value.trim().is_empty() => Ok(default),
        Ok(value) => value.trim().parse::<T>().map_err(|_| ConfigError::Invalid {
            var,
            reason: "khong phai so hop le",
        }),
    }
}

fn boolean(var: &'static str, default: bool) -> Result<bool, ConfigError> {
    match env::var(var) {
        Err(_) => Ok(default),
        Ok(value) if value.trim().is_empty() => Ok(default),
        Ok(value) => match value.trim().to_ascii_lowercase().as_str() {
            "true" | "1" | "yes" => Ok(true),
            "false" | "0" | "no" => Ok(false),
            _ => Err(ConfigError::Invalid {
                var,
                reason: "chi nhan true/false",
            }),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn key_vault_prefix_is_rejected() {
        let err = ConfigError::UnresolvedKeyVault("DB_PASSWORD");
        assert!(err.to_string().contains("DB_PASSWORD"));
        assert!("@Microsoft.KeyVault(SecretUri=https://x)".starts_with(KEY_VAULT_PREFIX));
    }

    #[test]
    fn error_message_never_contains_value() {
        let err = ConfigError::Invalid {
            var: "DB_PORT",
            reason: "khong phai so hop le",
        };
        let msg = err.to_string();
        assert!(msg.contains("DB_PORT"));
        assert!(!msg.contains("3306"));
    }
}

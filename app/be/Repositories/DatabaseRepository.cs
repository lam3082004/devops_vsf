using MySqlConnector;

namespace OpsBoard.Repositories;

public sealed class DatabaseRepository : IDatabaseRepository
{
    private readonly MySqlDataSource _dataSource;

    public DatabaseRepository(MySqlDataSource dataSource) => _dataSource = dataSource;

    /// Tạo bảng nếu chưa có. Chạy được nhiều lần (idempotent) nên khởi động
    /// lại app bao nhiêu lần cũng không lỗi. Bảng `nodes` cũ (domain Node) để
    /// yên trên Azure thật — chỉ là code không còn tạo/dùng nó nữa, không DROP.
    ///
    /// Thứ tự bắt buộc: tickets → comments → activities. `comments`/`activities`
    /// có FK trỏ vào `tickets` nên bảng đó phải tồn tại trước (MySQL từ chối FK
    /// tới bảng chưa có, errno 1824). MySqlConnector không cho multi-statement
    /// trong một CommandText nên mỗi CREATE TABLE một ExecuteNonQueryAsync
    /// riêng, tuần tự trên cùng connection — không bọc transaction vì DDL MySQL
    /// tự implicit-commit, bọc chỉ tạo ảo giác nguyên tử.
    public async Task EnsureSchemaAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);

        await using (var tickets = connection.CreateCommand())
        {
            tickets.CommandText = """
                CREATE TABLE IF NOT EXISTS tickets (
                    id           BIGINT        NOT NULL AUTO_INCREMENT,
                    title        VARCHAR(200)  NOT NULL,
                    description  TEXT          NULL,
                    severity     ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
                    category     ENUM('infra','app','database','network','security','other') NOT NULL DEFAULT 'other',
                    status       ENUM('open','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
                    reporter     VARCHAR(50)   NOT NULL,
                    assignee     VARCHAR(50)   NULL,
                    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    resolved_at  TIMESTAMP     NULL,
                    PRIMARY KEY (id),
                    KEY ix_tickets_status_updated (status, updated_at),
                    KEY ix_tickets_severity       (severity),
                    KEY ix_tickets_assignee       (assignee),
                    KEY ix_tickets_updated        (updated_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """;
            await tickets.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var comments = connection.CreateCommand())
        {
            comments.CommandText = """
                CREATE TABLE IF NOT EXISTS comments (
                    id         BIGINT       NOT NULL AUTO_INCREMENT,
                    ticket_id  BIGINT       NOT NULL,
                    author     VARCHAR(50)  NOT NULL,
                    body       VARCHAR(2000) NOT NULL,
                    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY ix_comments_ticket (ticket_id, created_at),
                    CONSTRAINT fk_comments_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """;
            await comments.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var activities = connection.CreateCommand())
        {
            activities.CommandText = """
                CREATE TABLE IF NOT EXISTS activities (
                    id          BIGINT       NOT NULL AUTO_INCREMENT,
                    ticket_id   BIGINT       NOT NULL,
                    actor       VARCHAR(50)  NOT NULL,
                    action      VARCHAR(30)  NOT NULL,
                    from_value  VARCHAR(200) NULL,
                    to_value    VARCHAR(200) NULL,
                    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY ix_activities_ticket (ticket_id, created_at),
                    CONSTRAINT fk_activities_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """;
            await activities.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    /// Không tự áp timeout ở đây — đó là quyết định của HealthService (chính
    /// sách "chờ bao lâu thì coi là chết" thuộc về nghiệp vụ, không phải
    /// truy cập dữ liệu).
    public async Task PingAsync(CancellationToken cancellationToken)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT 1";
        await command.ExecuteScalarAsync(cancellationToken);
    }
}

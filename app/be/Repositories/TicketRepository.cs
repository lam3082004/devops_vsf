using MySqlConnector;
using OpsBoard.Models;
using OpsBoard.Validation;

namespace OpsBoard.Repositories;

public sealed class TicketRepository : ITicketRepository
{
    private readonly MySqlDataSource _dataSource;

    public TicketRepository(MySqlDataSource dataSource) => _dataSource = dataSource;

    /// Dựng chung một mệnh đề WHERE (và tham số) rồi chạy HAI câu lệnh riêng:
    /// COUNT(*) không LIMIT/OFFSET lấy Total, và SELECT có LIMIT/OFFSET lấy
    /// Items — Total phải là tổng SAU KHI lọc, không phải Items.Count sau khi
    /// đã cắt limit.
    public async Task<(IReadOnlyList<Ticket> Items, int Total)> ListAsync(
        TicketListFilter filter, int limit, int offset, CancellationToken ct)
    {
        var where = new List<string>();
        var parameters = new List<(string Name, object Value)>();

        if (filter.Status is { } status)
        {
            where.Add("status = @status");
            parameters.Add(("@status", EnumNames<TicketStatus>.ToWire(status)));
        }

        if (filter.Severity is { } severity)
        {
            where.Add("severity = @severity");
            parameters.Add(("@severity", EnumNames<TicketSeverity>.ToWire(severity)));
        }

        if (filter.Category is { } category)
        {
            where.Add("category = @category");
            parameters.Add(("@category", EnumNames<TicketCategory>.ToWire(category)));
        }

        if (filter.Unassigned)
        {
            where.Add("assignee IS NULL");
        }
        else if (filter.Assignee is { } assignee)
        {
            where.Add("assignee = @assignee");
            parameters.Add(("@assignee", assignee));
        }

        if (filter.Q is { } q)
        {
            // q đã được validator escape %, _, \ — chỉ còn việc ghép pattern và
            // tham số hoá. ESCAPE '\\' khai rõ ký tự thoát cho LIKE (mặc định
            // MySQL đã dùng '\', khai tường minh để không phụ thuộc sql_mode
            // NO_BACKSLASH_ESCAPES).
            where.Add("title LIKE @q ESCAPE '\\\\'");
            parameters.Add(("@q", $"%{q}%"));
        }

        var whereSql = where.Count == 0 ? string.Empty : "WHERE " + string.Join(" AND ", where);

        await using var connection = await _dataSource.OpenConnectionAsync(ct);

        int total;
        await using (var countCommand = connection.CreateCommand())
        {
            countCommand.CommandText = $"SELECT COUNT(*) FROM tickets {whereSql}";
            foreach (var (name, value) in parameters)
            {
                countCommand.Parameters.AddWithValue(name, value);
            }

            total = Convert.ToInt32(await countCommand.ExecuteScalarAsync(ct));
        }

        var items = new List<Ticket>();
        await using (var listCommand = connection.CreateCommand())
        {
            listCommand.CommandText = $"""
                SELECT id, title, description, severity, category, status, reporter, assignee,
                       created_at, updated_at, resolved_at
                FROM tickets
                {whereSql}
                ORDER BY updated_at DESC
                LIMIT @limit OFFSET @offset
                """;
            foreach (var (name, value) in parameters)
            {
                listCommand.Parameters.AddWithValue(name, value);
            }

            listCommand.Parameters.AddWithValue("@limit", limit);
            listCommand.Parameters.AddWithValue("@offset", offset);

            await using var reader = await listCommand.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                items.Add(ReadTicket(reader));
            }
        }

        return (items, total);
    }

    /// Một transaction: insert ticket → insert activity 'created' → đọc lại
    /// ticket (lấy created_at/updated_at thật do MySQL tự điền). cmd.Transaction
    /// = tx cho MỌI command trong khối, kể cả SELECT đọc lại — MySqlConnector
    /// ném InvalidOperationException nếu command có Transaction = null khi
    /// connection đang mở transaction.
    public async Task<Ticket> CreateAsync(
        string title,
        string? description,
        TicketSeverity severity,
        TicketCategory category,
        string reporter,
        string? assignee,
        CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);
        await using var tx = await connection.BeginTransactionAsync(ct);

        long id;
        await using (var insert = connection.CreateCommand())
        {
            insert.Transaction = tx;
            insert.CommandText = """
                INSERT INTO tickets (title, description, severity, category, status, reporter, assignee)
                VALUES (@title, @description, @severity, @category, @status, @reporter, @assignee)
                """;
            insert.Parameters.AddWithValue("@title", title);
            insert.Parameters.AddWithValue("@description", (object?)description ?? DBNull.Value);
            insert.Parameters.AddWithValue("@severity", EnumNames<TicketSeverity>.ToWire(severity));
            insert.Parameters.AddWithValue("@category", EnumNames<TicketCategory>.ToWire(category));
            // status luôn 'open' lúc tạo mới (api-spec.md).
            insert.Parameters.AddWithValue("@status", EnumNames<TicketStatus>.ToWire(TicketStatus.Open));
            insert.Parameters.AddWithValue("@reporter", reporter);
            insert.Parameters.AddWithValue("@assignee", (object?)assignee ?? DBNull.Value);
            await insert.ExecuteNonQueryAsync(ct);
            id = insert.LastInsertedId;
        }

        await using (var insertActivity = connection.CreateCommand())
        {
            insertActivity.Transaction = tx;
            insertActivity.CommandText = """
                INSERT INTO activities (ticket_id, actor, action, from_value, to_value)
                VALUES (@ticketId, @actor, @action, NULL, NULL)
                """;
            insertActivity.Parameters.AddWithValue("@ticketId", id);
            insertActivity.Parameters.AddWithValue("@actor", reporter);
            insertActivity.Parameters.AddWithValue("@action", EnumNames<ActivityAction>.ToWire(ActivityAction.Created));
            await insertActivity.ExecuteNonQueryAsync(ct);
        }

        Ticket ticket;
        await using (var select = connection.CreateCommand())
        {
            select.Transaction = tx;
            select.CommandText = """
                SELECT id, title, description, severity, category, status, reporter, assignee,
                       created_at, updated_at, resolved_at
                FROM tickets WHERE id = @id
                """;
            select.Parameters.AddWithValue("@id", id);

            await using var reader = await select.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                throw new InvalidOperationException("ticket khong ton tai sau khi tao");
            }

            ticket = ReadTicket(reader);
        }

        await tx.CommitAsync(ct);
        return ticket;
    }

    public async Task<Ticket?> GetByIdAsync(long id, CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT id, title, description, severity, category, status, reporter, assignee,
                   created_at, updated_at, resolved_at
            FROM tickets WHERE id = @id
            """;
        command.Parameters.AddWithValue("@id", id);

        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? ReadTicket(reader) : null;
    }

    public async Task<IReadOnlyList<Activity>> ListActivitiesAsync(long ticketId, CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);
        await using var command = connection.CreateCommand();
        // ORDER BY created_at, id: tăng dần theo thời gian, id phá hoà khi hai
        // dòng cùng giây (cột TIMESTAMP chỉ có độ phân giải giây) — api-spec.md.
        command.CommandText = """
            SELECT id, ticket_id, actor, action, from_value, to_value, created_at
            FROM activities
            WHERE ticket_id = @ticketId
            ORDER BY created_at ASC, id ASC
            """;
        command.Parameters.AddWithValue("@ticketId", ticketId);

        var activities = new List<Activity>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            activities.Add(ReadActivity(reader));
        }

        return activities;
    }

    /// Một method = một transaction (be.md BE-3, mẫu UpdateAsync). Service đã
    /// quyết xong nghiệp vụ (field nào đổi, activity nào ghi, resolved_at set
    /// hay xoá) — repository chỉ còn việc ghi nguyên khối.
    public async Task<Ticket?> UpdateAsync(
        long id,
        TicketUpdate update,
        IReadOnlyList<ActivityWrite> activities,
        TicketStatus? expectedStatus,
        string actor,
        CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);
        await using var tx = await connection.BeginTransactionAsync(ct);

        var set = new List<string>();
        var parameters = new List<(string Name, object Value)>();

        if (update.Title is { } title)
        {
            set.Add("title = @title");
            parameters.Add(("@title", title));
        }

        if (update.DescriptionChanged)
        {
            set.Add("description = @description");
            parameters.Add(("@description", (object?)update.Description ?? DBNull.Value));
        }

        if (update.Severity is { } severity)
        {
            set.Add("severity = @severity");
            parameters.Add(("@severity", EnumNames<TicketSeverity>.ToWire(severity)));
        }

        if (update.Category is { } category)
        {
            set.Add("category = @category");
            parameters.Add(("@category", EnumNames<TicketCategory>.ToWire(category)));
        }

        if (update.AssigneeChanged)
        {
            set.Add("assignee = @assignee");
            parameters.Add(("@assignee", (object?)update.Assignee ?? DBNull.Value));
        }

        if (update.Status is { } status)
        {
            set.Add("status = @status");
            parameters.Add(("@status", EnumNames<TicketStatus>.ToWire(status)));
        }

        if (update.ResolvedAtChanged)
        {
            set.Add("resolved_at = @resolvedAt");
            parameters.Add(("@resolvedAt", (object?)update.ResolvedAt ?? DBNull.Value));
        }

        // @expected tham số hoá NULL khi không có precondition (PATCH field
        // thường); PATCH status truyền trạng thái HIỆN TẠI đã đọc được.
        object expectedParam = expectedStatus is { } expected
            ? EnumNames<TicketStatus>.ToWire(expected)
            : DBNull.Value;

        if (set.Count > 0)
        {
            await using var updateCommand = connection.CreateCommand();
            // cmd.Transaction = tx BẮT BUỘC cho MỌI command trong khối —
            // MySqlConnector ném InvalidOperationException nếu command có
            // Transaction = null trong khi connection đang mở transaction.
            updateCommand.Transaction = tx;
            updateCommand.CommandText = $"""
                UPDATE tickets SET {string.Join(", ", set)}
                WHERE id = @id AND (@expected IS NULL OR status = @expected)
                """;
            foreach (var (name, value) in parameters)
            {
                updateCommand.Parameters.AddWithValue(name, value);
            }

            updateCommand.Parameters.AddWithValue("@id", id);
            updateCommand.Parameters.AddWithValue("@expected", expectedParam);

            var affected = await updateCommand.ExecuteNonQueryAsync(ct);
            if (affected == 0)
            {
                // Có người đổi trạng thái trước (TOCTOU) hoặc ticket đã biến
                // mất giữa lúc service đọc và lúc ghi → rollback, trả null
                // (KHÔNG throw). Service map null này: đường status-change
                // (expectedStatus khác null) → 409; đường field-update
                // thường (expectedStatus null) → 404.
                await tx.RollbackAsync(ct);
                return null;
            }
        }
        else
        {
            // Không có cột nào thực sự đổi (PATCH body rỗng, hoặc mọi field
            // gửi lên đều giống hệt giá trị cũ). KHÔNG chạy UPDATE với SET
            // không-đổi-giá-trị (kiểu "SET id = id"): MySqlConnector mặc định
            // UseAffectedRows=true, nên một UPDATE không làm giá trị nào thực
            // sự đổi sẽ báo affected=0 dù hàng có tồn tại — nhầm với TOCTOU.
            // Thay vào đó kiểm tra đúng điều kiện (id + trạng thái mong đợi
            // nếu có) bằng một SELECT thuần trong CÙNG transaction.
            await using var checkCommand = connection.CreateCommand();
            checkCommand.Transaction = tx;
            checkCommand.CommandText =
                "SELECT 1 FROM tickets WHERE id = @id AND (@expected IS NULL OR status = @expected)";
            checkCommand.Parameters.AddWithValue("@id", id);
            checkCommand.Parameters.AddWithValue("@expected", expectedParam);

            var found = await checkCommand.ExecuteScalarAsync(ct);
            if (found is null)
            {
                await tx.RollbackAsync(ct);
                return null;
            }
        }

        foreach (var activity in activities)
        {
            await using var insertActivity = connection.CreateCommand();
            insertActivity.Transaction = tx;
            insertActivity.CommandText = """
                INSERT INTO activities (ticket_id, actor, action, from_value, to_value)
                VALUES (@ticketId, @actor, @action, @fromValue, @toValue)
                """;
            insertActivity.Parameters.AddWithValue("@ticketId", id);
            insertActivity.Parameters.AddWithValue("@actor", actor);
            insertActivity.Parameters.AddWithValue("@action", EnumNames<ActivityAction>.ToWire(activity.Action));
            insertActivity.Parameters.AddWithValue("@fromValue", (object?)activity.FromValue ?? DBNull.Value);
            insertActivity.Parameters.AddWithValue("@toValue", (object?)activity.ToValue ?? DBNull.Value);
            await insertActivity.ExecuteNonQueryAsync(ct);
        }

        // Đọc lại ticket TRONG transaction (cùng tx) để lấy updated_at mới do
        // ON UPDATE CURRENT_TIMESTAMP sinh ra, rồi mới CommitAsync.
        Ticket ticket;
        await using (var select = connection.CreateCommand())
        {
            select.Transaction = tx;
            select.CommandText = """
                SELECT id, title, description, severity, category, status, reporter, assignee,
                       created_at, updated_at, resolved_at
                FROM tickets WHERE id = @id
                """;
            select.Parameters.AddWithValue("@id", id);

            await using var reader = await select.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                throw new InvalidOperationException("ticket khong ton tai sau khi update");
            }

            ticket = ReadTicket(reader);
        }

        await tx.CommitAsync(ct);
        return ticket;
    }

    public async Task<IReadOnlyList<Comment>> ListCommentsAsync(long ticketId, CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);
        await using var command = connection.CreateCommand();
        // ORDER BY created_at, id: tăng dần theo thời gian, id phá hoà — giống
        // ListActivitiesAsync (api-spec.md, mục Comment).
        command.CommandText = """
            SELECT id, ticket_id, author, body, created_at
            FROM comments
            WHERE ticket_id = @ticketId
            ORDER BY created_at ASC, id ASC
            """;
        command.Parameters.AddWithValue("@ticketId", ticketId);

        var comments = new List<Comment>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            comments.Add(ReadComment(reader));
        }

        return comments;
    }

    /// Không transaction — chỉ một bảng, không kèm activity. Đọc lại row vừa
    /// tạo (như CreateAsync(Ticket) làm) để lấy created_at thật do MySQL tự
    /// điền.
    public async Task<Comment> CreateCommentAsync(long ticketId, string author, string body, CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);

        long id;
        await using (var insert = connection.CreateCommand())
        {
            insert.CommandText = """
                INSERT INTO comments (ticket_id, author, body)
                VALUES (@ticketId, @author, @body)
                """;
            insert.Parameters.AddWithValue("@ticketId", ticketId);
            insert.Parameters.AddWithValue("@author", author);
            insert.Parameters.AddWithValue("@body", body);
            await insert.ExecuteNonQueryAsync(ct);
            id = insert.LastInsertedId;
        }

        await using var select = connection.CreateCommand();
        select.CommandText = """
            SELECT id, ticket_id, author, body, created_at
            FROM comments WHERE id = @id
            """;
        select.Parameters.AddWithValue("@id", id);

        await using var reader = await select.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            throw new InvalidOperationException("comment khong ton tai sau khi tao");
        }

        return ReadComment(reader);
    }

    /// Bốn câu SELECT tuần tự trên cùng một connection — chỉ đọc, không cần
    /// transaction. AvgResolutionMinutes đọc bằng ExecuteScalarAsync: kết quả
    /// có thể là DBNull (chưa ticket nào resolved) hoặc decimal (MySqlConnector
    /// trả decimal cho AVG(...)) — KHÔNG ép kiểu thẳng bằng GetInt32.
    public async Task<TicketStatsRaw> GetStatsAsync(CancellationToken ct)
    {
        await using var connection = await _dataSource.OpenConnectionAsync(ct);

        var byStatus = new Dictionary<TicketStatus, int>();
        await using (var statusCommand = connection.CreateCommand())
        {
            statusCommand.CommandText = "SELECT status, COUNT(*) FROM tickets GROUP BY status";
            await using var reader = await statusCommand.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                if (!EnumNames<TicketStatus>.TryParse(reader.GetString(0), out var status))
                {
                    throw new InvalidOperationException("gia tri status trong DB khong hop le");
                }

                byStatus[status] = reader.GetInt32(1);
            }
        }

        var bySeverity = new Dictionary<TicketSeverity, int>();
        await using (var severityCommand = connection.CreateCommand())
        {
            severityCommand.CommandText = "SELECT severity, COUNT(*) FROM tickets GROUP BY severity";
            await using var reader = await severityCommand.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                if (!EnumNames<TicketSeverity>.TryParse(reader.GetString(0), out var severity))
                {
                    throw new InvalidOperationException("gia tri severity trong DB khong hop le");
                }

                bySeverity[severity] = reader.GetInt32(1);
            }
        }

        int total;
        await using (var totalCommand = connection.CreateCommand())
        {
            totalCommand.CommandText = "SELECT COUNT(*) FROM tickets";
            total = Convert.ToInt32(await totalCommand.ExecuteScalarAsync(ct));
        }

        int openCritical;
        await using (var openCriticalCommand = connection.CreateCommand())
        {
            openCriticalCommand.CommandText =
                "SELECT COUNT(*) FROM tickets WHERE severity = @severity AND status = @status";
            openCriticalCommand.Parameters.AddWithValue("@severity", EnumNames<TicketSeverity>.ToWire(TicketSeverity.Critical));
            openCriticalCommand.Parameters.AddWithValue("@status", EnumNames<TicketStatus>.ToWire(TicketStatus.Open));
            openCritical = Convert.ToInt32(await openCriticalCommand.ExecuteScalarAsync(ct));
        }

        long? avgResolutionMinutes;
        await using (var avgCommand = connection.CreateCommand())
        {
            avgCommand.CommandText =
                "SELECT AVG(TIMESTAMPDIFF(MINUTE, created_at, resolved_at)) FROM tickets WHERE resolved_at IS NOT NULL";
            var raw = await avgCommand.ExecuteScalarAsync(ct);
            avgResolutionMinutes = raw is null or DBNull
                ? null
                : Convert.ToInt64(Math.Round(Convert.ToDecimal(raw), MidpointRounding.AwayFromZero));
        }

        return new TicketStatsRaw(byStatus, bySeverity, total, openCritical, avgResolutionMinutes);
    }

    private static Comment ReadComment(MySqlDataReader reader) => new(
        Id: reader.GetInt64("id"),
        TicketId: reader.GetInt64("ticket_id"),
        Author: reader.GetString("author"),
        Body: reader.GetString("body"),
        CreatedAt: DateTime.SpecifyKind(reader.GetDateTime("created_at"), DateTimeKind.Utc));

    private static Activity ReadActivity(MySqlDataReader reader)
    {
        var fromOrdinal = reader.GetOrdinal("from_value");
        var toOrdinal = reader.GetOrdinal("to_value");

        if (!EnumNames<ActivityAction>.TryParse(reader.GetString("action"), out var action))
        {
            throw new InvalidOperationException("gia tri action trong DB khong hop le");
        }

        return new Activity(
            Id: reader.GetInt64("id"),
            TicketId: reader.GetInt64("ticket_id"),
            Actor: reader.GetString("actor"),
            Action: action,
            FromValue: reader.IsDBNull(fromOrdinal) ? null : reader.GetString(fromOrdinal),
            ToValue: reader.IsDBNull(toOrdinal) ? null : reader.GetString(toOrdinal),
            CreatedAt: DateTime.SpecifyKind(reader.GetDateTime("created_at"), DateTimeKind.Utc));
    }

    /// MySqlConnector KHÔNG tự map cột ENUM sang enum C# — đọc bằng
    /// reader.GetString rồi tự parse bằng EnumNames (KHÔNG dùng
    /// reader.GetFieldValue<T>()). Parse hỏng nghĩa là dữ liệu trong DB hỏng,
    /// coi như lỗi hạ tầng — ném để DatabaseExceptionFilter bắt thành 503.
    private static Ticket ReadTicket(MySqlDataReader reader)
    {
        var descriptionOrdinal = reader.GetOrdinal("description");
        var assigneeOrdinal = reader.GetOrdinal("assignee");
        var resolvedAtOrdinal = reader.GetOrdinal("resolved_at");

        if (!EnumNames<TicketSeverity>.TryParse(reader.GetString("severity"), out var severity))
        {
            throw new InvalidOperationException("gia tri severity trong DB khong hop le");
        }

        if (!EnumNames<TicketCategory>.TryParse(reader.GetString("category"), out var category))
        {
            throw new InvalidOperationException("gia tri category trong DB khong hop le");
        }

        if (!EnumNames<TicketStatus>.TryParse(reader.GetString("status"), out var status))
        {
            throw new InvalidOperationException("gia tri status trong DB khong hop le");
        }

        return new Ticket(
            Id: reader.GetInt64("id"),
            Title: reader.GetString("title"),
            Description: reader.IsDBNull(descriptionOrdinal) ? null : reader.GetString(descriptionOrdinal),
            Severity: severity,
            Category: category,
            Status: status,
            Reporter: reader.GetString("reporter"),
            Assignee: reader.IsDBNull(assigneeOrdinal) ? null : reader.GetString(assigneeOrdinal),
            CreatedAt: DateTime.SpecifyKind(reader.GetDateTime("created_at"), DateTimeKind.Utc),
            UpdatedAt: DateTime.SpecifyKind(reader.GetDateTime("updated_at"), DateTimeKind.Utc),
            ResolvedAt: reader.IsDBNull(resolvedAtOrdinal)
                ? null
                : DateTime.SpecifyKind(reader.GetDateTime(resolvedAtOrdinal), DateTimeKind.Utc));
    }
}

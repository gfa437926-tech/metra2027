using Npgsql;
using Testcontainers.PostgreSql;
using Metra.Api.Features.EquipmentFaults;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

/// <summary>
/// Exercises the actual migration, RLS, transaction-local context, station scoping,
/// atomic audit trigger and transition rollback against PostgreSQL 17.
/// </summary>
public sealed class NpgsqlEquipmentFaultStoreIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:17-alpine")
        .WithDatabase("metra_faults_test")
        .WithUsername("postgres")
        .WithPassword("postgres-test-only")
        .Build();

    private NpgsqlDataSource _dataSource = null!;
    private NpgsqlEquipmentFaultStore _store = null!;
    private readonly Guid _actorId = Guid.NewGuid();
    private readonly Guid _stationId = Guid.NewGuid();
    private readonly Guid _otherStationId = Guid.NewGuid();

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        await using var admin = new NpgsqlConnection(_postgres.GetConnectionString());
        await admin.OpenAsync();
        await ExecuteAsync(admin, """
            create schema auth;
            create table auth.users (id uuid primary key);
            create table public.station_catalogue (id uuid primary key);
            create role anon nologin;
            create role authenticated nologin;
            create role metra_api_runtime nologin inherit;
            create role service_role nologin bypassrls;
            """);

        var migrationPath = Path.Combine(
            AppContext.BaseDirectory, "Migrations", "20261108060000_equipment_faults_npgsql.sql");
        var migrationSql = await File.ReadAllTextAsync(migrationPath);
        await ExecuteAsync(admin, migrationSql);

        await ExecuteAsync(admin, """
            alter role metra_equipment_faults_login password 'integration-only-password';
            """);
        await using (var seedUser = new NpgsqlCommand(
            "insert into auth.users(id) values (@actor)", admin))
        {
            seedUser.Parameters.AddWithValue("actor", _actorId);
            await seedUser.ExecuteNonQueryAsync();
        }
        await using (var seedStations = new NpgsqlCommand(
            "insert into public.station_catalogue(id) values (@station), (@other_station)", admin))
        {
            seedStations.Parameters.AddWithValue("station", _stationId);
            seedStations.Parameters.AddWithValue("other_station", _otherStationId);
            await seedStations.ExecuteNonQueryAsync();
        }

        var loginConnection = new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
        {
            Username = "metra_equipment_faults_login",
            Password = "integration-only-password",
            SslMode = SslMode.Disable,
            Pooling = false
        };
        _dataSource = NpgsqlDataSource.Create(loginConnection.ConnectionString);
        _store = new NpgsqlEquipmentFaultStore(_dataSource);
    }

    public async Task DisposeAsync()
    {
        if (_dataSource is not null)
            await _dataSource.DisposeAsync();
        await _postgres.DisposeAsync();
    }

    [Fact]
    public async Task RLS_station_scope_and_atomic_audit_work_for_create_and_transition()
    {
        var faultId = await CreateFaultAsync();

        var ownPage = await _store.GetPageAsync(
            _actorId, _stationId, new EquipmentFaultListQuery(), new EquipmentFaultListWindow(1, 25, 0));
        var otherPage = await _store.GetPageAsync(
            _actorId, _otherStationId, new EquipmentFaultListQuery(), new EquipmentFaultListWindow(1, 25, 0));
        var wrongStationOwner = await _store.GetOwningStationIdAsync(
            _actorId, _otherStationId, faultId, CancellationToken.None);

        Assert.Single(ownPage.Items);
        Assert.Empty(otherPage.Items);
        Assert.Null(wrongStationOwner);

        var transition = await _store.TryTransitionAsync(
            faultId, _stationId, EquipmentFaultStatus.Submitted,
            EquipmentFaultStatus.UnderReview, _actorId, "مراجعة البلاغ");

        Assert.Equal(EquipmentFaultTransitionWriteResult.Applied, transition);
        var detail = await _store.GetDetailAsync(_actorId, faultId, _stationId);
        Assert.NotNull(detail);
        Assert.Equal(EquipmentFaultStatus.UnderReview, detail.Status);

        await using var admin = new NpgsqlConnection(_postgres.GetConnectionString());
        await admin.OpenAsync();
        await using var auditCount = new NpgsqlCommand(
            "select count(*) from public.equipment_fault_audit where fault_id = @id", admin);
        auditCount.Parameters.AddWithValue("id", faultId);
        Assert.Equal(2L, (long)(await auditCount.ExecuteScalarAsync())!);

        await using var auditMutation = new NpgsqlCommand(
            "update public.equipment_fault_audit set reason = 'tampered audit' where fault_id = @id", admin);
        auditMutation.Parameters.AddWithValue("id", faultId);
        await Assert.ThrowsAsync<PostgresException>(() => auditMutation.ExecuteNonQueryAsync());
    }

    [Fact]
    public async Task Audit_failure_rolls_back_the_fault_status_update()
    {
        var faultId = await CreateFaultAsync();
        await using (var admin = new NpgsqlConnection(_postgres.GetConnectionString()))
        {
            await admin.OpenAsync();
            await ExecuteAsync(admin, """
                create function public.fail_equipment_fault_audit_test()
                returns trigger language plpgsql as $$
                begin
                  raise exception 'forced audit failure';
                end;
                $$;
                create trigger fail_equipment_fault_audit_test
                before insert on public.equipment_fault_audit
                for each row execute function public.fail_equipment_fault_audit_test();
                """);
        }

        await Assert.ThrowsAsync<PostgresException>(() => _store.TryTransitionAsync(
            faultId, _stationId, EquipmentFaultStatus.Submitted,
            EquipmentFaultStatus.UnderReview, _actorId, "مراجعة البلاغ"));

        await using (var admin = new NpgsqlConnection(_postgres.GetConnectionString()))
        {
            await admin.OpenAsync();
            await using var status = new NpgsqlCommand(
                "select status from public.equipment_faults where id = @id", admin);
            status.Parameters.AddWithValue("id", faultId);
            Assert.Equal("Submitted", (string)(await status.ExecuteScalarAsync())!);

            await ExecuteAsync(admin, """
                drop trigger fail_equipment_fault_audit_test on public.equipment_fault_audit;
                drop function public.fail_equipment_fault_audit_test();
                """);
        }
    }

    [Fact]
    public async Task Concurrent_transitions_produce_one_winner_and_one_conflict()
    {
        var faultId = await CreateFaultAsync();
        var start = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        var review = Task.Run(async () =>
        {
            await start.Task;
            return await _store.TryTransitionAsync(
                faultId, _stationId, EquipmentFaultStatus.Submitted,
                EquipmentFaultStatus.UnderReview, _actorId, "مراجعة البلاغ");
        });
        var reject = Task.Run(async () =>
        {
            await start.Task;
            return await _store.TryTransitionAsync(
                faultId, _stationId, EquipmentFaultStatus.Submitted,
                EquipmentFaultStatus.Rejected, _actorId, "رفض البلاغ");
        });

        start.SetResult(true);
        var results = await Task.WhenAll(review, reject);

        Assert.Single(results, result => result == EquipmentFaultTransitionWriteResult.Applied);
        Assert.Single(results, result => result == EquipmentFaultTransitionWriteResult.Conflict);

        var detail = await _store.GetDetailAsync(_actorId, faultId, _stationId);
        Assert.NotNull(detail);
        Assert.Contains(detail.Status, new[] { EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Rejected });

        await using var admin = new NpgsqlConnection(_postgres.GetConnectionString());
        await admin.OpenAsync();
        await using var auditCount = new NpgsqlCommand(
            "select count(*) from public.equipment_fault_audit where fault_id = @id", admin);
        auditCount.Parameters.AddWithValue("id", faultId);
        Assert.Equal(2L, (long)(await auditCount.ExecuteScalarAsync())!);
    }

    [Fact]
    public async Task Runtime_login_cannot_update_or_delete_audit_rows()
    {
        var faultId = await CreateFaultAsync();
        var loginConnection = new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
        {
            Username = "metra_equipment_faults_login",
            Password = "integration-only-password",
            SslMode = SslMode.Disable,
            Pooling = false
        };

        await using (var connection = new NpgsqlConnection(loginConnection.ConnectionString))
        {
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            await using (var role = new NpgsqlCommand(
                "set local role metra_equipment_faults_runtime", connection, transaction))
                await role.ExecuteNonQueryAsync();
            await using var update = new NpgsqlCommand(
                "update public.equipment_fault_audit set reason = 'تعديل غير مصرح' where fault_id = @id",
                connection, transaction);
            update.Parameters.AddWithValue("id", faultId);
            await Assert.ThrowsAsync<PostgresException>(() => update.ExecuteNonQueryAsync());
        }

        await using (var connection = new NpgsqlConnection(loginConnection.ConnectionString))
        {
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync();
            await using (var role = new NpgsqlCommand(
                "set local role metra_equipment_faults_runtime", connection, transaction))
                await role.ExecuteNonQueryAsync();
            await using var delete = new NpgsqlCommand(
                "delete from public.equipment_fault_audit where fault_id = @id",
                connection, transaction);
            delete.Parameters.AddWithValue("id", faultId);
            await Assert.ThrowsAsync<PostgresException>(() => delete.ExecuteNonQueryAsync());
        }
    }

    [Fact]
    public async Task Undefined_or_forbidden_transition_is_denied_before_database_write()
    {
        var faultId = await CreateFaultAsync();

        var result = await _store.TryTransitionAsync(
            faultId, _stationId, EquipmentFaultStatus.Submitted,
            EquipmentFaultStatus.Closed, _actorId, "محاولة انتقال غير مسموح");

        Assert.Equal(EquipmentFaultTransitionWriteResult.Forbidden, result);
        var detail = await _store.GetDetailAsync(_actorId, faultId, _stationId);
        Assert.Equal(EquipmentFaultStatus.Submitted, detail!.Status);
    }

    private async Task<Guid> CreateFaultAsync() =>
        await _store.CreateAsync(
            _actorId,
            _stationId,
            new EquipmentFaultSubmission(
                "أجهزة الرصد",
                "مقياس الحرارة",
                "توقف الجهاز عن إرسال القراءات",
                EquipmentFaultSeverity.High,
                DateTimeOffset.UtcNow,
                false));

    private static async Task ExecuteAsync(NpgsqlConnection connection, string sql)
    {
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}

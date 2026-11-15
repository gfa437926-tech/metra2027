using System.Security.Cryptography;
using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecorderImageUploadIntakeServiceTests
{
    private static readonly Guid ActorId = Guid.NewGuid();
    private static readonly Guid CaptureId = Guid.NewGuid();
    private static readonly Guid AssetId = Guid.NewGuid();
    private static readonly byte[] PngBytes =
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

    private static RecorderImageUploadRequest Request() =>
        new(CaptureId, AssetId, "chart.png", "image/png",
            Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant(),
            "corr_123");

    [Fact]
    public async Task Rejects_unauthorized_actor_before_asset_lookup_or_storage()
    {
        var authorizer = new FakeAuthorizer { Allowed = false };
        var store = new FakeAssetStore();
        var storage = new FakeStorage();
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("upload_not_authorized", result.ErrorCode);
        Assert.Equal(1, authorizer.Calls);
        Assert.Equal(0, store.ReadCalls);
        Assert.Equal(0, storage.WriteCalls);
    }

    [Fact]
    public async Task Valid_upload_is_written_to_quarantine_and_atomically_recorded()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore { CommitResult = RecorderQuarantineCommitResult.Committed };
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length,
                Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant(),
                "image/png")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.True(result.IsAccepted);
        Assert.Equal(AssetId, result.AssetId);
        Assert.Equal(1, storage.WriteCalls);
        Assert.Equal(1, store.CommitCalls);
        Assert.Equal(RecordImageAssetStatus.AwaitingUpload, store.ExpectedState);
        Assert.NotNull(store.AuditEvent);
        Assert.True(RecorderSecurityAuditEventPolicy.IsValid(store.AuditEvent));
        Assert.Equal(0, storage.DeleteCalls);
    }

    [Fact]
    public async Task Removes_quarantine_object_when_storage_metadata_does_not_match_validated_bytes()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length, new string('a', 64), "image/png")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.False(result.IsAccepted);
        Assert.Equal("stored_object_integrity_mismatch", result.ErrorCode);
        Assert.Equal(1, storage.DeleteCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Removes_quarantine_object_when_stored_length_differs_from_received_bytes()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var hash = Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length + 1, hash, "image/png")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("stored_object_integrity_mismatch", result.ErrorCode);
        Assert.Equal(1, storage.DeleteCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Removes_quarantine_object_when_detected_media_type_differs_from_validated_bytes()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var hash = Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length, hash, "image/jpeg")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("stored_object_integrity_mismatch", result.ErrorCode);
        Assert.Equal(1, storage.DeleteCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Removes_only_the_current_attempt_when_storage_returns_another_attempt_id()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var hash = Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length, hash, "image/png"),
            ReturnWrongUploadAttemptId = true
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("storage_upload_attempt_mismatch", result.ErrorCode);
        Assert.Equal(1, storage.DeleteCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Removes_quarantine_object_when_asset_compare_and_set_conflicts()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore { CommitResult = RecorderQuarantineCommitResult.StateConflict };
        var hash = Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length, hash, "image/png")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("asset_state_conflict", result.ErrorCode);
        Assert.Equal(1, storage.DeleteCalls);
    }

    [Fact]
    public async Task Preserves_private_quarantine_when_commit_outcome_is_unknown()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore
        {
            CommitResult = RecorderQuarantineCommitResult.OutcomeUnknown
        };
        var hash = Convert.ToHexString(SHA256.HashData(PngBytes)).ToLowerInvariant();
        var storage = new FakeStorage
        {
            StoredObject = new(AssetId, Guid.Empty, PngBytes.Length, hash, "image/png")
        };
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(),
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("upload_commit_outcome_unknown", result.ErrorCode);
        Assert.Equal(1, store.CommitCalls);
        Assert.Equal(0, storage.DeleteCalls);
    }

    [Fact]
    public async Task Rejects_missing_actor_without_calling_any_dependency()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var storage = new FakeStorage();
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);

        var result = await service.UploadAsync(
            null, Request(), new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("authenticated_actor_required", result.ErrorCode);
        Assert.Equal(0, authorizer.Calls);
        Assert.Equal(0, store.ReadCalls);
        Assert.Equal(0, storage.WriteCalls);
    }

    [Fact]
    public async Task Rejects_asset_outside_awaiting_upload_state_before_reading_or_storing_bytes()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore
        {
            CurrentState = RecordImageAssetStatus.UploadedQuarantined
        };
        var storage = new FakeStorage();
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);
        await using var source = new ThrowOnReadStream();

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), Request(), source, CancellationToken.None);

        Assert.Equal("asset_not_awaiting_upload", result.ErrorCode);
        Assert.Equal(1, authorizer.Calls);
        Assert.Equal(1, store.ReadCalls);
        Assert.Equal(0, storage.WriteCalls);
    }

    [Fact]
    public async Task Rejects_invalid_correlation_token_before_authorization()
    {
        var authorizer = new FakeAuthorizer { Allowed = true };
        var store = new FakeAssetStore();
        var storage = new FakeStorage();
        var service = new RecorderImageUploadIntakeService(authorizer, store, storage);
        var request = Request() with { CorrelationId = "bad correlation" };

        var result = await service.UploadAsync(
            new RecorderImageUploadActor(ActorId), request,
            new MemoryStream(PngBytes), CancellationToken.None);

        Assert.Equal("upload_correlation_invalid", result.ErrorCode);
        Assert.Equal(0, authorizer.Calls);
        Assert.Equal(0, store.ReadCalls);
        Assert.Equal(0, storage.WriteCalls);
    }

    private sealed class ThrowOnReadStream : Stream
    {
        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) =>
            throw new InvalidOperationException("The stream must not be read.");
        public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("The stream must not be read.");
        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }

    private sealed class FakeAuthorizer : IRecorderImageUploadAuthorizer
    {
        public bool Allowed { get; init; }
        public int Calls { get; private set; }

        public Task<bool> AuthorizeAsync(
            Guid actorSubjectId, Guid captureId, Guid assetId,
            CancellationToken cancellationToken)
        {
            Calls++;
            Assert.Equal(ActorId, actorSubjectId);
            Assert.Equal(CaptureId, captureId);
            Assert.Equal(AssetId, assetId);
            return Task.FromResult(Allowed);
        }
    }

    private sealed class FakeAssetStore : IRecorderImageAssetIntakeStore
    {
        public RecorderQuarantineCommitResult CommitResult { get; init; }
        public RecordImageAssetStatus CurrentState { get; init; } = RecordImageAssetStatus.AwaitingUpload;
        public int ReadCalls { get; private set; }
        public int CommitCalls { get; private set; }
        public RecordImageAssetStatus? ExpectedState { get; private set; }
        public RecorderSecurityAuditEvent? AuditEvent { get; private set; }

        public Task<RecordImageAssetStatus?> GetStatusAsync(
            Guid assetId, CancellationToken cancellationToken)
        {
            ReadCalls++;
            return Task.FromResult<RecordImageAssetStatus?>(CurrentState);
        }

        public Task<RecorderQuarantineCommitResult> TryRecordQuarantinedAsync(
            Guid assetId, RecordImageAssetStatus expectedState,
            QuarantinedRecorderObject storedObject,
            RecorderSecurityAuditEvent auditEvent,
            CancellationToken cancellationToken)
        {
            CommitCalls++;
            ExpectedState = expectedState;
            AuditEvent = auditEvent;
            return Task.FromResult(CommitResult);
        }
    }

    private sealed class FakeStorage : IRecorderQuarantineStorage
    {
        public QuarantinedRecorderObject? StoredObject { get; init; }
        public bool ReturnWrongUploadAttemptId { get; init; }
        public int WriteCalls { get; private set; }
        public int DeleteCalls { get; private set; }

        public Task<QuarantinedRecorderObject> WriteQuarantinedAsync(
            Guid assetId, Guid uploadAttemptId, Stream content, long maximumBytes,
            CancellationToken cancellationToken)
        {
            WriteCalls++;
            Assert.Equal(AssetId, assetId);
            Assert.NotEqual(Guid.Empty, uploadAttemptId);
            Assert.Equal(RecordImageUploadValidator.MaximumBytes, maximumBytes);
            var stored = StoredObject! with
            {
                UploadAttemptId = ReturnWrongUploadAttemptId ? Guid.NewGuid() : uploadAttemptId
            };
            return Task.FromResult(stored);
        }

        public Task<Stream> OpenQuarantinedReadAsync(
            Guid assetId, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task PromoteAcceptedAsync(
            Guid assetId, string verifiedSha256,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task DeleteQuarantinedAsync(
            Guid assetId, Guid uploadAttemptId, CancellationToken cancellationToken)
        {
            DeleteCalls++;
            Assert.NotEqual(Guid.Empty, uploadAttemptId);
            return Task.CompletedTask;
        }

        public Task DeleteExpiredQuarantineAsync(
            Guid assetId, CancellationToken cancellationToken) =>
            Task.CompletedTask;
    }
}

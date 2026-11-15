using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecorderDigitizationSubmissionServiceTests
{
    private static readonly Guid ActorId = Guid.NewGuid();
    private static readonly Guid CaptureId = Guid.NewGuid();
    private static readonly Guid AssetId = Guid.NewGuid();

    private static RecorderDigitizationSubmission Request() =>
        new(CaptureId, AssetId, "thermograph-v1", "metra:submit-12345");

    private sealed class Authorizer(bool allowed = true) : IRecorderDigitizationSubmissionAuthorizer
    {
        public int Calls { get; private set; }
        public Task<bool> CanDigitizeCaptureAssetAsync(Guid actorSubjectId, Guid captureId, Guid assetId, CancellationToken cancellationToken)
        {
            Calls++;
            Assert.Equal(ActorId, actorSubjectId);
            Assert.Equal(CaptureId, captureId);
            Assert.Equal(AssetId, assetId);
            return Task.FromResult(allowed);
        }
    }

    private sealed class AssetReader(RecordImageAssetStatus? status = RecordImageAssetStatus.Accepted) : IRecorderAssetStatusReader
    {
        public int Calls { get; private set; }
        public Task<RecordImageAssetStatus?> GetStatusAsync(Guid assetId, CancellationToken cancellationToken)
        {
            Calls++;
            Assert.Equal(AssetId, assetId);
            return Task.FromResult(status);
        }
    }

    private sealed class Outbox(RecorderDigitizationOutboxWriteResult? result = null) : IRecorderDigitizationOutbox
    {
        public int Calls { get; private set; }
        public string? LastFingerprint { get; private set; }
        public Task<RecorderDigitizationOutboxWriteResult> TryCreateAsync(Guid actorSubjectId, RecorderDigitizationSubmission submission, string requestFingerprint, CancellationToken cancellationToken)
        {
            Calls++;
            Assert.Equal(ActorId, actorSubjectId);
            Assert.Equal(Request(), submission);
            Assert.True(RecordDigitizationRequestFingerprint.TryCompute(submission, out var expectedFingerprint));
            Assert.Equal(expectedFingerprint, requestFingerprint);
            Assert.Matches("^[0-9a-f]{64}$", requestFingerprint);
            LastFingerprint = requestFingerprint;
            return Task.FromResult(result ?? new(
                RecorderDigitizationOutboxWriteStatus.Created, Guid.NewGuid()));
        }
    }

    [Fact]
    public async Task Rejects_missing_actor_before_accessing_dependencies()
    {
        var authorizer = new Authorizer();
        var reader = new AssetReader();
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(authorizer, reader, outbox);

        var result = await service.SubmitAsync(null, Request(), CancellationToken.None);

        Assert.Equal("authenticated_actor_required", result.ErrorCode);
        Assert.Equal(0, authorizer.Calls);
        Assert.Equal(0, reader.Calls);
        Assert.Equal(0, outbox.Calls);
    }

    [Fact]
    public async Task Rejects_unauthorized_actor_without_reading_asset_or_writing_outbox()
    {
        var authorizer = new Authorizer(allowed: false);
        var reader = new AssetReader();
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(authorizer, reader, outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.Equal("digitization_permission_denied", result.ErrorCode);
        Assert.Equal(1, authorizer.Calls);
        Assert.Equal(0, reader.Calls);
        Assert.Equal(0, outbox.Calls);
    }

    [Fact]
    public async Task Rejects_missing_asset_without_outbox_write()
    {
        var authorizer = new Authorizer();
        var reader = new AssetReader(status: null);
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(authorizer, reader, outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.Equal("asset_not_found", result.ErrorCode);
        Assert.Equal(0, outbox.Calls);
    }

    [Theory]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined)]
    [InlineData(RecordImageAssetStatus.Scanning)]
    [InlineData(RecordImageAssetStatus.Rejected)]
    [InlineData(RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.Cancelled)]
    public async Task Rejects_asset_not_in_accepted_state(RecordImageAssetStatus status)
    {
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(
            new Authorizer(), new AssetReader(status), outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.Equal("asset_not_accepted", result.ErrorCode);
        Assert.Equal(0, outbox.Calls);
    }

    [Fact]
    public async Task Writes_authorized_accepted_submission_to_transactional_outbox()
    {
        var expectedJobId = Guid.NewGuid();
        var outbox = new Outbox(new(RecorderDigitizationOutboxWriteStatus.Created, expectedJobId));
        var service = new RecorderDigitizationSubmissionService(
            new Authorizer(), new AssetReader(), outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.True(result.IsAccepted);
        Assert.Equal(expectedJobId, result.JobId);
        Assert.False(result.WasPreviouslySubmitted);
        Assert.Equal(1, outbox.Calls);
        Assert.NotNull(outbox.LastFingerprint);
    }

    [Fact]
    public async Task Returns_existing_job_for_same_idempotent_request()
    {
        var expectedJobId = Guid.NewGuid();
        var outbox = new Outbox(new(RecorderDigitizationOutboxWriteStatus.ExistingSameRequest, expectedJobId));
        var service = new RecorderDigitizationSubmissionService(
            new Authorizer(), new AssetReader(), outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.True(result.IsAccepted);
        Assert.Equal(expectedJobId, result.JobId);
        Assert.True(result.WasPreviouslySubmitted);
    }

    [Fact]
    public async Task Rejects_reused_idempotency_key_with_different_payload()
    {
        var outbox = new Outbox(new(RecorderDigitizationOutboxWriteStatus.IdempotencyConflict, null));
        var service = new RecorderDigitizationSubmissionService(
            new Authorizer(), new AssetReader(), outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.Equal("idempotency_key_conflict", result.ErrorCode);
        Assert.False(result.IsAccepted);
    }

    [Fact]
    public async Task Rejects_outbox_result_without_valid_job_identifier()
    {
        var outbox = new Outbox(new(RecorderDigitizationOutboxWriteStatus.Created, Guid.Empty));
        var service = new RecorderDigitizationSubmissionService(
            new Authorizer(), new AssetReader(), outbox);

        var result = await service.SubmitAsync(new(ActorId), Request(), CancellationToken.None);

        Assert.Equal("digitization_submission_unavailable", result.ErrorCode);
    }
    [Fact]
    public async Task Rejects_empty_capture_identifier_without_calling_dependencies()
    {
        var authorizer = new Authorizer();
        var reader = new AssetReader();
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(authorizer, reader, outbox);
        var request = Request() with { CaptureId = Guid.Empty };

        var result = await service.SubmitAsync(new(ActorId), request, CancellationToken.None);

        Assert.Equal("digitization_resource_required", result.ErrorCode);
        Assert.Equal(0, authorizer.Calls);
        Assert.Equal(0, reader.Calls);
        Assert.Equal(0, outbox.Calls);
    }

    [Fact]
    public async Task Rejects_empty_asset_identifier_without_calling_dependencies()
    {
        var authorizer = new Authorizer();
        var reader = new AssetReader();
        var outbox = new Outbox();
        var service = new RecorderDigitizationSubmissionService(authorizer, reader, outbox);
        var request = Request() with { AcceptedAssetId = Guid.Empty };

        var result = await service.SubmitAsync(new(ActorId), request, CancellationToken.None);

        Assert.Equal("digitization_resource_required", result.ErrorCode);
        Assert.Equal(0, authorizer.Calls);
        Assert.Equal(0, reader.Calls);
        Assert.Equal(0, outbox.Calls);
    }

}

using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordImageAssetTransitionPolicyTests
{
    private static readonly RecordImageInspection CleanInspection =
        new(RecordImageScanVerdict.Clean, "scanner", "1.2.3", null);

    private static readonly RecordImageIntegrityEvidence ValidIntegrity =
        new(true, true, true, 1024);

    [Fact]
    public void Allows_acceptance_only_when_lifecycle_and_security_evidence_pass()
    {
        var result = RecordImageAssetTransitionPolicy.Evaluate(
            RecordImageAssetStatus.Scanning,
            RecordImageAssetStatus.Accepted,
            CleanInspection,
            ValidIntegrity);

        Assert.True(result.IsAllowed);
        Assert.Equal(RecordImageAssetStatus.Scanning, result.From);
        Assert.Equal(RecordImageAssetStatus.Accepted, result.To);
    }

    [Fact]
    public void Keeps_acceptance_transition_blocked_when_evidence_is_missing()
    {
        var missingInspection = RecordImageAssetTransitionPolicy.Evaluate(
            RecordImageAssetStatus.Scanning,
            RecordImageAssetStatus.Accepted,
            null,
            ValidIntegrity);
        var missingIntegrity = RecordImageAssetTransitionPolicy.Evaluate(
            RecordImageAssetStatus.Scanning,
            RecordImageAssetStatus.Accepted,
            CleanInspection,
            null);

        Assert.Equal("inspection_evidence_missing", missingInspection.ErrorCode);
        Assert.Equal("inspection_evidence_missing", missingIntegrity.ErrorCode);
    }

    [Fact]
    public void Blocks_acceptance_for_unknown_or_non_clean_scanner_verdicts()
    {
        var unknown = CleanInspection with { Verdict = (RecordImageScanVerdict)999 };
        var threat = CleanInspection with { Verdict = RecordImageScanVerdict.ThreatDetected };

        Assert.Equal("scanner_result_unknown",
            RecordImageAssetTransitionPolicy.Evaluate(
                RecordImageAssetStatus.Scanning,
                RecordImageAssetStatus.Accepted,
                unknown,
                ValidIntegrity).ErrorCode);

        Assert.Equal("content_threat_detected",
            RecordImageAssetTransitionPolicy.Evaluate(
                RecordImageAssetStatus.Scanning,
                RecordImageAssetStatus.Accepted,
                threat,
                ValidIntegrity).ErrorCode);
    }

    [Fact]
    public void Does_not_allow_security_evidence_to_bypass_lifecycle_rules()
    {
        var result = RecordImageAssetTransitionPolicy.Evaluate(
            RecordImageAssetStatus.UploadedQuarantined,
            RecordImageAssetStatus.Accepted,
            CleanInspection,
            ValidIntegrity);

        Assert.Equal("invalid_asset_state_transition", result.ErrorCode);
    }

    [Fact]
    public void Preserves_non_acceptance_lifecycle_transitions()
    {
        var result = RecordImageAssetTransitionPolicy.Evaluate(
            RecordImageAssetStatus.UploadedQuarantined,
            RecordImageAssetStatus.Scanning,
            null,
            null);

        Assert.True(result.IsAllowed);
        Assert.Equal(RecordImageAssetStatus.Scanning, result.To);
    }
}

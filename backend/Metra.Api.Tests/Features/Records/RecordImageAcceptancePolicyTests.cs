using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordImageAcceptancePolicyTests
{
    private static readonly RecordImageInspection CleanInspection =
        new(RecordImageScanVerdict.Clean, "scanner", "1.2.3", null);

    private static readonly RecordImageIntegrityEvidence ValidIntegrity =
        new(true, true, true, 1024);

    [Fact]
    public void Accepts_only_scanning_asset_with_clean_scan_and_complete_integrity()
    {
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.Scanning, CleanInspection, ValidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.Accept, result.Action);
        Assert.Equal("image_security_checks_passed", result.ReasonCode);
    }

    [Fact]
    public void Never_accepts_asset_outside_scanning_state()
    {
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.UploadedQuarantined, CleanInspection, ValidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.Reject, result.Action);
        Assert.Equal("asset_not_scanning", result.ReasonCode);
    }

    [Fact]
    public void Keeps_asset_quarantined_when_scanner_is_indeterminate()
    {
        var inspection = CleanInspection with { Verdict = RecordImageScanVerdict.Indeterminate };
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.Scanning, inspection, ValidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.KeepQuarantined, result.Action);
    }

    [Fact]
    public void Rejects_threat_and_integrity_failures()
    {
        var threat = CleanInspection with { Verdict = RecordImageScanVerdict.ThreatDetected };
        Assert.Equal(RecordImageAcceptanceAction.Reject,
            RecordImageAcceptancePolicy.Evaluate(
                RecordImageAssetStatus.Scanning, threat, ValidIntegrity).Action);

        var badHash = ValidIntegrity with { Sha256Verified = false };
        Assert.Equal(RecordImageAcceptanceAction.Reject,
            RecordImageAcceptancePolicy.Evaluate(
                RecordImageAssetStatus.Scanning, CleanInspection, badHash).Action);
    }

    [Fact]
    public void Keeps_asset_quarantined_for_unknown_scan_verdict()
    {
        var unknownVerdict = CleanInspection with { Verdict = (RecordImageScanVerdict)999 };
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.Scanning, unknownVerdict, ValidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.KeepQuarantined, result.Action);
        Assert.Equal("scanner_result_unknown", result.ReasonCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("scanner\nforged")]
    [InlineData("scanner\tforged")]
    [InlineData("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")]
    public void Keeps_asset_quarantined_for_invalid_scanner_identity(string scannerName)
    {
        var invalidIdentity = CleanInspection with { ScannerName = scannerName };
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.Scanning, invalidIdentity, ValidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.KeepQuarantined, result.Action);
        Assert.Equal("scanner_identity_missing", result.ReasonCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(20971521)]
    public void Rejects_non_positive_or_oversized_integrity_length(long actualLength)
    {
        var invalidIntegrity = ValidIntegrity with { ActualLength = actualLength };
        var result = RecordImageAcceptancePolicy.Evaluate(
            RecordImageAssetStatus.Scanning, CleanInspection, invalidIntegrity);

        Assert.Equal(RecordImageAcceptanceAction.Reject, result.Action);
        Assert.Equal("image_integrity_policy_failed", result.ReasonCode);
    }

    [Fact]
    public void Keeps_asset_quarantined_when_scanner_identity_or_evidence_is_missing()
    {
        var missingVersion = CleanInspection with { ScannerVersion = "" };
        Assert.Equal(RecordImageAcceptanceAction.KeepQuarantined,
            RecordImageAcceptancePolicy.Evaluate(
                RecordImageAssetStatus.Scanning, missingVersion, ValidIntegrity).Action);

        Assert.Equal(RecordImageAcceptanceAction.KeepQuarantined,
            RecordImageAcceptancePolicy.Evaluate(
                RecordImageAssetStatus.Scanning, null, ValidIntegrity).Action);
    }
}

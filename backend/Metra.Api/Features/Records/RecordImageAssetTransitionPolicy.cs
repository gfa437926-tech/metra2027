namespace Metra.Api.Features.Records;

/// <summary>
/// Combines lifecycle validation with the mandatory evidence gate for the
/// security-sensitive Scanning -> Accepted transition. Persistence adapters
/// must use this policy rather than RecordImageAssetState alone when committing
/// an acceptance transition.
/// </summary>
public static class RecordImageAssetTransitionPolicy
{
    public static RecordImageAssetTransition Evaluate(
        RecordImageAssetStatus current,
        RecordImageAssetStatus requested,
        RecordImageInspection? inspection,
        RecordImageIntegrityEvidence? integrity)
    {
        var lifecycle = RecordImageAssetState.Evaluate(current, requested);
        if (!lifecycle.IsAllowed)
            return lifecycle;

        if (requested != RecordImageAssetStatus.Accepted)
            return lifecycle;

        var acceptance = RecordImageAcceptancePolicy.Evaluate(
            current, inspection, integrity);

        return acceptance.Action == RecordImageAcceptanceAction.Accept
            ? lifecycle
            : RecordImageAssetTransition.Rejected(acceptance.ReasonCode);
    }
}

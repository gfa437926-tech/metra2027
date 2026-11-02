namespace Metra.Api.Domain.Identity;

public enum MetraAccountLifecycleCommand
{
    Suspend = 0,
    Restore = 1,
    Disable = 2
}

public sealed record MetraAccountLifecycleTransition(
    MetraAccountAccessState From,
    MetraAccountLifecycleCommand Command,
    MetraAccountAccessState To);

public sealed record MetraAccountLifecycleResult(
    bool Succeeded,
    MetraAccountAccessState CurrentState,
    MetraAccountLifecycleTransition? Transition,
    string Code);

/// <summary>
/// Pure account lifecycle rules. Actor authorization, transactional persistence,
/// concurrency checks and immutable audit append are application/store duties.
/// Disabled is terminal; restoring a suspended account is explicit and never
/// recreates or widens permission grants.
/// </summary>
public static class MetraAccountLifecyclePolicy
{
    public static MetraAccountLifecycleResult Apply(
        MetraAccountAccessState currentState,
        MetraAccountLifecycleCommand command)
    {
        if (!Enum.IsDefined(currentState))
            return Deny(currentState, "account_state_invalid");

        if (!Enum.IsDefined(command))
            return Deny(currentState, "account_lifecycle_command_invalid");

        var next = (currentState, command) switch
        {
            (MetraAccountAccessState.Active, MetraAccountLifecycleCommand.Suspend)
                => MetraAccountAccessState.Suspended,
            (MetraAccountAccessState.Active, MetraAccountLifecycleCommand.Disable)
                => MetraAccountAccessState.Disabled,
            (MetraAccountAccessState.Suspended, MetraAccountLifecycleCommand.Restore)
                => MetraAccountAccessState.Active,
            (MetraAccountAccessState.Suspended, MetraAccountLifecycleCommand.Disable)
                => MetraAccountAccessState.Disabled,
            _ => (MetraAccountAccessState?)null
        };

        if (next is null)
            return Deny(currentState, currentState == MetraAccountAccessState.Disabled
                ? "account_disabled_terminal"
                : "account_lifecycle_transition_invalid");

        return new(
            true,
            next.Value,
            new(currentState, command, next.Value),
            "account_lifecycle_transition_valid");
    }

    private static MetraAccountLifecycleResult Deny(
        MetraAccountAccessState state,
        string code)
        => new(false, state, null, code);
}

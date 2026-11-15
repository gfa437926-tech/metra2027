namespace Metra.Api.Features.Records;

/// <summary>
/// Reads an untrusted upload stream with a hard byte limit. It never trusts
/// Content-Length or stream seekability and stops after observing byte max + 1.
/// </summary>
public static class RecordImageBoundedStreamReader
{
    private const int BufferSize = 81920;

    public static async Task<RecordImageBoundedReadResult> ReadAsync(
        Stream source,
        int maximumBytes,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(source);

        if (!source.CanRead)
            return RecordImageBoundedReadResult.Reject("upload_stream_not_readable");

        if (maximumBytes <= 0)
            return RecordImageBoundedReadResult.Reject("upload_size_limit_invalid");

        await using var buffer = new MemoryStream(
            capacity: Math.Min(maximumBytes, BufferSize));

        var chunk = new byte[Math.Min(BufferSize, maximumBytes + 1)];
        while (true)
        {
            var remainingIncludingOverflowByte = maximumBytes + 1 - (int)buffer.Length;
            var requested = Math.Min(chunk.Length, remainingIncludingOverflowByte);
            var read = await source.ReadAsync(
                chunk.AsMemory(0, requested), cancellationToken);

            if (read == 0)
                break;

            if (read > maximumBytes - buffer.Length)
                return RecordImageBoundedReadResult.Reject("file_too_large");

            await buffer.WriteAsync(chunk.AsMemory(0, read), cancellationToken);
        }

        if (buffer.Length == 0)
            return RecordImageBoundedReadResult.Reject("empty_file");

        return new(true, null, buffer.ToArray());
    }
}

public sealed record RecordImageBoundedReadResult(
    bool IsAccepted,
    string? ErrorCode,
    byte[]? Content)
{
    public static RecordImageBoundedReadResult Reject(string errorCode) =>
        new(false, errorCode, null);
}

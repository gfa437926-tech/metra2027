using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordImageBoundedStreamReaderTests
{
    [Fact]
    public async Task Reads_non_seekable_stream_within_limit()
    {
        var bytes = Enumerable.Range(0, 64).Select(value => (byte)value).ToArray();
        await using var source = new NonSeekableReadStream(bytes);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, bytes.Length, CancellationToken.None);

        Assert.True(result.IsAccepted);
        Assert.Null(result.ErrorCode);
        Assert.Equal(bytes, result.Content);
    }

    [Fact]
    public async Task Rejects_stream_that_exceeds_limit_without_returning_partial_content()
    {
        await using var source = new NonSeekableReadStream(new byte[129]);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, 128, CancellationToken.None);

        Assert.False(result.IsAccepted);
        Assert.Equal("file_too_large", result.ErrorCode);
        Assert.Null(result.Content);
    }

    [Fact]
    public async Task Accepts_exact_limit_without_reading_past_it()
    {
        var bytes = new byte[128];
        await using var source = new NonSeekableReadStream(bytes);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, 128, CancellationToken.None);

        Assert.True(result.IsAccepted);
        Assert.Equal(bytes, result.Content);
    }

    [Fact]
    public async Task Rejects_empty_stream()
    {
        await using var source = new NonSeekableReadStream([]);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, 128, CancellationToken.None);

        Assert.Equal("empty_file", result.ErrorCode);
    }

    [Fact]
    public async Task Rejects_non_readable_stream()
    {
        await using var source = new NonSeekableReadStream([], canRead: false);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, 128, CancellationToken.None);

        Assert.Equal("upload_stream_not_readable", result.ErrorCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task Rejects_invalid_limits(int limit)
    {
        await using var source = new NonSeekableReadStream([1]);

        var result = await RecordImageBoundedStreamReader.ReadAsync(
            source, limit, CancellationToken.None);

        Assert.Equal("upload_size_limit_invalid", result.ErrorCode);
    }

    [Fact]
    public async Task Honors_cancellation()
    {
        await using var source = new BlockingReadStream();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            RecordImageBoundedStreamReader.ReadAsync(source, 128, cancellation.Token));
    }

    private sealed class NonSeekableReadStream(byte[] bytes, bool canRead = true) : Stream
    {
        private int _position;
        public override bool CanRead => canRead;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override ValueTask<int> ReadAsync(Memory<byte> destination, CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!canRead) throw new NotSupportedException();
            var count = Math.Min(destination.Length, bytes.Length - _position);
            bytes.AsMemory(_position, count).CopyTo(destination);
            _position += count;
            return ValueTask.FromResult(count);
        }
        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }

    private sealed class BlockingReadStream : Stream
    {
        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override ValueTask<int> ReadAsync(Memory<byte> destination, CancellationToken cancellationToken = default) =>
            ValueTask.FromCanceled<int>(cancellationToken);
        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
}

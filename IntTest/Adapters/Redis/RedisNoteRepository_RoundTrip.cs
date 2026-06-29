using AtomiCloud.DotnetBase.App.Adapters.Redis;
using AtomiCloud.DotnetBase.Lib.Note;
using FluentAssertions;
using StackExchange.Redis;
using Testcontainers.Redis;

namespace AtomiCloud.DotnetBase.IntTest.Adapters.Redis;

/// <summary>
/// Proves the Redis adapter round trip against a real Redis instance started by
/// Testcontainers. A fresh container per test class keeps state isolated.
/// </summary>
public class RedisNoteRepository_RoundTrip : IAsyncLifetime
{
    private readonly RedisContainer _redis = new RedisBuilder("redis:7-alpine")
        .Build();

    private IConnectionMultiplexer _connection = null!;

    public async ValueTask InitializeAsync()
    {
        await _redis.StartAsync();
        _connection = await ConnectionMultiplexer.ConnectAsync(_redis.GetConnectionString());
    }

    public async ValueTask DisposeAsync()
    {
        // _connection stays null if StartAsync threw before it was assigned (e.g. Docker
        // unavailable); guard so disposal doesn't mask the real initialisation failure.
        if (_connection is not null) await _connection.DisposeAsync();
        await _redis.DisposeAsync();
    }

    [Fact]
    public async Task It_should_persist_a_note_and_read_the_same_value_back()
    {
        // Arrange
        var subject = new RedisNoteRepository(_connection);
        var input = new NoteRecord { Title = "Round trip", Body = "stored in Redis" };

        // Act
        var saved = await subject.Save(input);
        var actual = await subject.Find(saved.Id);

        // Assert
        actual.Should().NotBeNull();
        actual!.Id.Should().Be(saved.Id);
        actual.Record.Should().Be(input);
    }

    [Fact]
    public async Task It_should_return_null_when_the_note_is_absent()
    {
        // Arrange
        var subject = new RedisNoteRepository(_connection);

        // Act
        var actual = await subject.Find("missing");

        // Assert
        actual.Should().BeNull();
    }
}

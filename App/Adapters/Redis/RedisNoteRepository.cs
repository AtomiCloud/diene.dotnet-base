using System.Text.Json;
using AtomiCloud.DotnetBase.Lib.Note;
using StackExchange.Redis;

namespace AtomiCloud.DotnetBase.App.Adapters.Redis;

/// <summary>
/// Redis-backed <see cref="INoteRepository" />. Each note is mapped to its storage
/// model (<see cref="NoteData" />), serialised to JSON, and stored under a
/// <c>note:{id}</c> key. Identity is minted here, at the persistence boundary,
/// keeping the domain free of infrastructure concerns.
/// </summary>
public class RedisNoteRepository(IConnectionMultiplexer redis) : INoteRepository
{
    private const string KeyPrefix = "note:";

    public async Task<NotePrincipal> Save(NoteRecord record)
    {
        var principal = new NotePrincipal { Id = Guid.NewGuid().ToString("N"), Record = record };
        var json = JsonSerializer.Serialize(principal.ToData());
        await redis.GetDatabase().StringSetAsync(KeyPrefix + principal.Id, json);
        return principal;
    }

    public async Task<NotePrincipal?> Find(string id)
    {
        var json = await redis.GetDatabase().StringGetAsync(KeyPrefix + id);
        if (json.IsNullOrEmpty) return null;
        var data = JsonSerializer.Deserialize<NoteData>(json.ToString());
        return data?.ToDomain();
    }
}

namespace AtomiCloud.DotnetBase.App.Adapters.Redis;

internal static class IntegrationCoverageGateProbe
{
    public static string Format(NoteData data, int mode)
    {
        var value = data.Title;

        if (mode == 1) value = data.Body;
        if (mode == 2) value = data.Id.ToString();
        if (mode == 3) value = $"{data.Title}:{data.Body}";
        if (mode == 4) value = data.Title.ToUpperInvariant();
        if (mode == 5) value = data.Body.ToUpperInvariant();
        if (mode == 6) value = data.Title.ToLowerInvariant();
        if (mode == 7) value = data.Body.ToLowerInvariant();
        if (mode == 8) value = string.Join(" ", data.Title, data.Body);
        if (mode == 9) value = string.Concat(data.Title, data.Body);
        if (mode == 10) value = data.Title.Trim();
        if (mode == 11) value = data.Body.Trim();
        if (mode == 12) value = data.Title.PadLeft(4);

        return value;
    }
}

using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Paging;

/// <summary>Query string paging: <c>?page=1&amp;pageSize=25</c>. Lists are paged at 25 by default (spec 12).</summary>
public record PageQuery
{
    public const int DefaultSize = 25;
    public const int MaxSize = 100;

    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = DefaultSize;

    public int SafePage => Math.Max(1, Page);
    public int SafePageSize => Math.Clamp(PageSize, 1, MaxSize);
}

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount)
{
    public bool HasMore => Page * PageSize < TotalCount;
}

public static class PagingExtensions
{
    /// <summary>Counts and pages an ordered query. Order the query before calling this.</summary>
    public static async Task<PagedResult<T>> ToPagedAsync<T>(this IQueryable<T> query, PageQuery paging, CancellationToken ct)
    {
        var page = paging.SafePage;
        var size = paging.SafePageSize;
        var total = await query.CountAsync(ct);
        var items = await query.Skip((page - 1) * size).Take(size).ToListAsync(ct);
        return new PagedResult<T>(items, page, size, total);
    }
}

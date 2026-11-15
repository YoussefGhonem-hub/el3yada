using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Common;

/// <summary>A page of a list: <c>?page=1&amp;pageSize=25</c> (spec section 12: lists show 25 per page).</summary>
public interface IPagedQuery
{
    int Page { get; }

    int PageSize { get; }
}

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount)
{
    public int TotalPages => PageSize == 0 ? 0 : (TotalCount + PageSize - 1) / PageSize;
}

public static class Paging
{
    public const int DefaultPageSize = 25;
    public const int MaxPageSize = 100;

    public static async Task<PagedResult<T>> ToPageAsync<T>(
        this IQueryable<T> query, IPagedQuery paging, CancellationToken cancellationToken)
    {
        var total = await query.CountAsync(cancellationToken);
        var items = await query
            .Skip((paging.Page - 1) * paging.PageSize)
            .Take(paging.PageSize)
            .ToListAsync(cancellationToken);
        return new PagedResult<T>(items, paging.Page, paging.PageSize, total);
    }

    /// <summary>page ≥ 1 and 1 ≤ pageSize ≤ 100.</summary>
    public static void AddPagingRules<T>(this AbstractValidator<T> validator)
        where T : IPagedQuery
    {
        validator.RuleFor(x => x.Page).GreaterThanOrEqualTo(1).WithErrorCode(ErrorCodes.OutOfRange);
        validator.RuleFor(x => x.PageSize).InclusiveBetween(1, MaxPageSize).WithErrorCode(ErrorCodes.OutOfRange);
    }
}

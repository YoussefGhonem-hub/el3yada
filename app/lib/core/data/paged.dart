/// A page of a list, as every paged endpoint answers it (`?page=1&pageSize=25`,
/// backend/docs/api-phase-1.md "Paging"). Load lists with `PagedController`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory Paged.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic> json) item) => Paged(
        items: [for (final row in json['items'] as List) item((row as Map).cast<String, dynamic>())],
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
        totalCount: json['totalCount'] as int,
        totalPages: json['totalPages'] as int,
      );

  /// One page holding all of [items] (fakes and tests).
  factory Paged.single(List<T> items) =>
      Paged(items: items, page: 1, pageSize: items.isEmpty ? 25 : items.length, totalCount: items.length, totalPages: 1);

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}

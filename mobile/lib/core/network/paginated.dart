/// A page of items as returned by paginated endpoints:
/// `{ "items": [...], "pagination": { page, page_size, total, total_pages } }`.
class Paginated<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const Paginated({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory Paginated.fromJson(Map<String, dynamic> data, T Function(Map<String, dynamic>) parse) {
    final items = (data['items'] as List? ?? const []).map((e) => parse(e as Map<String, dynamic>)).toList();
    final p = data['pagination'] as Map<String, dynamic>? ?? const {};
    return Paginated(
      items: items,
      page: p['page'] as int? ?? 1,
      pageSize: p['page_size'] as int? ?? items.length,
      total: p['total'] as int? ?? items.length,
      totalPages: p['total_pages'] as int? ?? 1,
    );
  }
}

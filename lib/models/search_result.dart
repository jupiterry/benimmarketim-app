import 'product.dart';

class SearchResult {
  final bool success;
  final List<Product> products;
  final int total;
  final String searchTerm;

  SearchResult({
    required this.success,
    required this.products,
    required this.total,
    required this.searchTerm,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      success: json['success'] ?? false,
      products: (json['products'] as List? ?? [])
          .map((product) => Product.fromJson(product))
          .toList(),
      total: json['total'] ?? 0,
      searchTerm: json['searchTerm'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'products': products.map((product) => product.toJson()).toList(),
      'total': total,
      'searchTerm': searchTerm,
    };
  }
}

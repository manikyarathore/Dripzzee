import 'models/fashion_category.dart';
import 'models/product.dart';
import 'models/store.dart';

class SearchResults {
  const SearchResults({
    required this.products,
    required this.stores,
    required this.suggestions,
  });

  final List<Product> products;
  final List<Store> stores;
  final List<String> suggestions;

  bool get isEmpty => products.isEmpty && stores.isEmpty;

  static const empty =
      SearchResults(products: [], stores: [], suggestions: []);
}

List<String> tokenize(String query) => query
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9₹]+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// Client-side search over the nearby catalog: products, brands, stores,
/// categories, colours and style tags. Every token must match.
SearchResults searchCatalog(
  String query,
  List<Product> products,
  List<Store> stores,
) {
  final tokens = tokenize(query);
  if (tokens.isEmpty) return SearchResults.empty;

  int scoreProduct(Product p) {
    final name = p.name.toLowerCase();
    final brand = p.brand.toLowerCase();
    var score = 0;
    for (final t in tokens) {
      if (name.startsWith(t)) {
        score += 6;
      } else if (name.contains(t)) {
        score += 4;
      } else if (brand.contains(t)) {
        score += 3;
      } else if (p.tags.any((tag) => tag.startsWith(t))) {
        score += 2;
      } else {
        score += 1;
      }
    }
    return score + (p.inStock ? 2 : 0);
  }

  final matchedProducts = products
      .where((p) => p.active && tokens.every(p.searchText.contains))
      .toList()
    ..sort((a, b) => scoreProduct(b).compareTo(scoreProduct(a)));

  final matchedStores = stores.where((s) {
    final text = [s.name, s.description, ...s.categories, ...s.tags]
        .join(' ')
        .toLowerCase();
    return tokens.every(text.contains);
  }).toList();

  final q = query.trim().toLowerCase();
  final pool = <String>{
    for (final c in kCategories) c.label,
    for (final p in products) ...[p.name, if (p.brand.isNotEmpty) p.brand],
    for (final s in stores) s.name,
  };
  final suggestions = pool
      .where((s) {
        final lower = s.toLowerCase();
        return lower != q &&
            (lower.startsWith(q) || lower.contains(' $q'));
      })
      .take(6)
      .toList();

  return SearchResults(
    products: matchedProducts,
    stores: matchedStores,
    suggestions: suggestions,
  );
}

import 'package:customer_app/data/catalog_search.dart';
import 'package:customer_app/data/models/catalog_filter.dart';
import 'package:customer_app/data/models/product.dart';
import 'package:customer_app/data/models/store.dart';
import 'package:flutter_test/flutter_test.dart';

Product p(String id, String name, {String brand = '', List<String> tags = const [], int price = 1000, List<String> colors = const []}) =>
    Product(
      id: id,
      storeId: 's1',
      storeName: 'Kesariya Boutique',
      name: name,
      brand: brand,
      description: '',
      category: 'ethnic',
      price: price,
      mrp: null,
      images: const [],
      tags: tags,
      colors: colors,
      sizes: const {'M': 2},
      active: true,
      createdAt: null,
      trendingScore: 0,
    );

void main() {
  final store = Store.fromMap('s1', {
    'name': 'Kesariya Boutique',
    'categories': ['ethnic'],
    'tags': ['festive'],
    'lat': 0,
    'lng': 0,
  });
  final products = [
    p('1', 'Mirror-work Chaniya Choli', brand: 'Kesariya', tags: ['garba', 'navratri'], colors: ['Red']),
    p('2', 'Cotton Kurta Set', tags: ['festive'], price: 800),
    p('3', 'White Sneakers', brand: 'Stride'),
  ];

  test('matches names, tags, colours and store names', () {
    expect(searchCatalog('chaniya', products, [store]).products.map((e) => e.id), ['1']);
    expect(searchCatalog('garba red', products, [store]).products.map((e) => e.id), ['1']);
    expect(searchCatalog('kesariya', products, [store]).stores, hasLength(1));
    expect(searchCatalog('zzz', products, [store]).isEmpty, isTrue);
    expect(searchCatalog('   ', products, [store]).isEmpty, isTrue);
  });

  test('suggestions are prefix matches', () {
    final s = searchCatalog('kur', products, [store]).suggestions;
    expect(s, contains('Cotton Kurta Set'));
  });

  test('filters and sorting', () {
    const garba = ProductFilter(title: 'Garba', tag: 'garba');
    expect(products.where(garba.matches).map((e) => e.id), ['1']);
    final sorted = sortProducts(products, ProductSort.priceLowHigh);
    expect(sorted.first.id, '2');
  });
}

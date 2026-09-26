import 'package:customer_app/data/models/cart_item.dart';
import 'package:customer_app/data/models/product.dart';
import 'package:customer_app/state/cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

CartItem item({
  String product = 'p1',
  String store = 's1',
  String size = 'M',
  int price = 1000,
  int qty = 1,
  int stock = 5,
}) =>
    CartItem(
      productId: product,
      storeId: store,
      storeName: 'Store $store',
      storeDeliveryFee: 49,
      name: 'Item $product',
      imageUrl: null,
      size: size,
      color: null,
      unitPrice: price,
      mrp: null,
      quantity: qty,
      maxStock: stock,
    );

Product product(String id, {int price = 1000, Map<String, int>? sizes, bool active = true}) =>
    Product(
      id: id,
      storeId: 's1',
      storeName: 'Store s1',
      name: 'Item $id',
      brand: '',
      description: '',
      category: 'women',
      price: price,
      mrp: null,
      images: const [],
      tags: const [],
      colors: const [],
      sizes: sizes ?? const {'M': 5},
      active: active,
      createdAt: null,
      trendingScore: 0,
    );

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemoryCartStorage storage;
  late CartController cart;

  setUp(() async {
    storage = MemoryCartStorage();
    cart = CartController(storage: storage)..bindUser('u1');
    await flush();
  });

  test('adding the same product+size merges quantities', () {
    expect(cart.add(item()), AddToCartResult.added);
    expect(cart.add(item()), AddToCartResult.added);
    expect(cart.items, hasLength(1));
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 2000);
  });

  test('single-retailer rule blocks another store until replaced', () {
    cart.add(item(store: 's1'));
    expect(cart.add(item(product: 'p2', store: 's2')),
        AddToCartResult.differentStore);
    expect(cart.storeId, 's1');
    expect(cart.replaceWith(item(product: 'p2', store: 's2')),
        AddToCartResult.added);
    expect(cart.storeId, 's2');
    expect(cart.items, hasLength(1));
  });

  test('cannot exceed stock or add sold-out sizes', () {
    expect(cart.add(item(qty: 2, stock: 2)), AddToCartResult.added);
    expect(cart.add(item(stock: 2)), AddToCartResult.limitReached);
    expect(cart.add(item(size: 'L', stock: 0)), AddToCartResult.outOfStock);
  });

  test('setQuantity caps at stock and removes at zero', () {
    cart.add(item(stock: 3));
    final key = cart.items.single.key;
    cart.setQuantity(key, 10);
    expect(cart.items.single.quantity, 3);
    cart.setQuantity(key, 0);
    expect(cart.isEmpty, isTrue);
  });

  test('price breakdown applies delivery and platform fees', () {
    cart.add(item(price: 500));
    var bill = cart.breakdown;
    expect(bill.deliveryFee, 49);
    expect(bill.platformFee, 5);
    expect(bill.total, 554);
    expect(bill.amountToFreeDelivery, 499);

    cart.add(item(price: 500));
    bill = cart.breakdown;
    expect(bill.subtotal, 1000);
    expect(bill.deliveryFee, 0);
    expect(bill.total, 1005);
  });

  test('reconcile removes unavailable items, updates price and stock', () {
    cart.add(item(product: 'a', qty: 3, stock: 5));
    cart.add(item(product: 'b'));
    cart.add(item(product: 'c'));
    final notes = cart.reconcile([
      product('a', price: 1200, sizes: {'M': 2}),
      product('b', active: false),
      // 'c' was deleted entirely
    ]);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.quantity, 2);
    expect(cart.items.single.unitPrice, 1200);
    expect(notes, hasLength(4));
  });

  test('cart persists per user', () async {
    cart.add(item());
    await flush();
    final again = CartController(storage: storage)..bindUser('u1');
    await flush();
    await flush();
    expect(again.items, hasLength(1));

    final other = CartController(storage: storage)..bindUser('u2');
    await flush();
    expect(other.isEmpty, isTrue);
  });
}

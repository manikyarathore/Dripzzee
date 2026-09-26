import '../../core/utils/parse.dart';

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.address,
    required this.rating,
    required this.ratingCount,
    required this.categories,
    required this.tags,
    required this.lat,
    required this.lng,
    required this.deliveryFee,
    required this.minDeliveryMinutes,
    required this.maxDeliveryMinutes,
    required this.pickupAvailable,
    required this.returnPolicy,
    required this.returnWindowDays,
    required this.active,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String address;
  final double rating;
  final int ratingCount;
  final List<String> categories;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final int deliveryFee;
  final int minDeliveryMinutes;
  final int maxDeliveryMinutes;
  final bool pickupAvailable;
  final String returnPolicy;
  final int returnWindowDays;
  final bool active;

  /// Computed client-side from the customer's selected location.
  final double? distanceKm;

  bool get hasRating => ratingCount > 0;
  String get etaLabel => '$minDeliveryMinutes–$maxDeliveryMinutes min';
  String get categoryLine => categories.take(3).join(' • ');

  factory Store.fromMap(String id, Map<String, dynamic> d) {
    final minEta = readInt(d['minDeliveryMinutes'], 30);
    return Store(
      id: id,
      name: readString(d['name'], 'Store'),
      description: readString(d['description']),
      imageUrl: readString(d['imageUrl']),
      address: readString(d['address']),
      rating: readDouble(d['rating']),
      ratingCount: readInt(d['ratingCount']),
      categories: readStringList(d['categories']),
      tags: readStringList(d['tags']),
      lat: readDoubleOrNull(d['lat']),
      lng: readDoubleOrNull(d['lng']),
      deliveryFee: readInt(d['deliveryFee'], 49),
      minDeliveryMinutes: minEta,
      maxDeliveryMinutes: readInt(d['maxDeliveryMinutes'], minEta + 20),
      pickupAvailable: readBool(d['pickupAvailable'], true),
      returnPolicy: readString(
        d['returnPolicy'],
        'Returns and size exchanges accepted within 7 days of delivery for unused items with tags.',
      ),
      returnWindowDays: readInt(d['returnWindowDays'], 7),
      active: readBool(d['active'], true),
    );
  }

  Store withDistance(double? km) => Store(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        address: address,
        rating: rating,
        ratingCount: ratingCount,
        categories: categories,
        tags: tags,
        lat: lat,
        lng: lng,
        deliveryFee: deliveryFee,
        minDeliveryMinutes: minDeliveryMinutes,
        maxDeliveryMinutes: maxDeliveryMinutes,
        pickupAvailable: pickupAvailable,
        returnPolicy: returnPolicy,
        returnWindowDays: returnWindowDays,
        active: active,
        distanceKm: km,
      );
}

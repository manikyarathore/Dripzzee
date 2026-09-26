import 'package:flutter/material.dart';

import 'catalog_filter.dart';

class FashionCategory {
  const FashionCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.filter,
  });

  final String id;
  final String label;
  final IconData icon;
  final ProductFilter filter;
}

/// Category ids match `products.category` values written by the retailer app
/// and seed script. Festive/New are cross-cutting (tag / recency).
const kCategories = <FashionCategory>[
  FashionCategory(
    id: 'women',
    label: 'Women',
    icon: Icons.woman_2_outlined,
    filter: ProductFilter(title: 'Women', category: 'women'),
  ),
  FashionCategory(
    id: 'men',
    label: 'Men',
    icon: Icons.man_2_outlined,
    filter: ProductFilter(title: 'Men', category: 'men'),
  ),
  FashionCategory(
    id: 'ethnic',
    label: 'Ethnic',
    icon: Icons.auto_awesome_outlined,
    filter: ProductFilter(title: 'Ethnic & traditional', category: 'ethnic'),
  ),
  FashionCategory(
    id: 'festive',
    label: 'Festive',
    icon: Icons.celebration_outlined,
    filter: ProductFilter(title: 'Festive picks', tag: 'festive'),
  ),
  FashionCategory(
    id: 'sneakers',
    label: 'Sneakers',
    icon: Icons.directions_run_rounded,
    filter: ProductFilter(title: 'Sneakers', category: 'sneakers'),
  ),
  FashionCategory(
    id: 'streetwear',
    label: 'Streetwear',
    icon: Icons.checkroom_outlined,
    filter: ProductFilter(title: 'Streetwear', category: 'streetwear'),
  ),
  FashionCategory(
    id: 'accessories',
    label: 'Accessories',
    icon: Icons.watch_outlined,
    filter: ProductFilter(title: 'Accessories', category: 'accessories'),
  ),
  FashionCategory(
    id: 'new',
    label: 'New in',
    icon: Icons.fiber_new_outlined,
    filter: ProductFilter(
      title: 'New arrivals',
      newArrivalsOnly: true,
      sort: ProductSort.newest,
    ),
  ),
];

String categoryLabel(String id) {
  for (final c in kCategories) {
    if (c.id == id) return c.label;
  }
  if (id.isEmpty) return 'Fashion';
  return id[0].toUpperCase() + id.substring(1);
}

IconData categoryIcon(String id) {
  for (final c in kCategories) {
    if (c.id == id) return c.icon;
  }
  return Icons.checkroom_outlined;
}

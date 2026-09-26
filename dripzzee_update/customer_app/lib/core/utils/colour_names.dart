import 'package:flutter/material.dart';

/// Maps retailer colour names to swatches for filter chips. Unknown names
/// fall back to a neutral grey (the chip still shows the name).
const Map<String, Color> _swatches = {
  'marigold': Color(0xFFF5B942),
  'ivory': Color(0xFFEDE6D8),
  'cream': Color(0xFFF1E7D0),
  'white': Color(0xFFF5F5F5),
  'black': Color(0xFF151515),
  'red': Color(0xFFE5484D),
  'maroon': Color(0xFF7A1F2B),
  'pink': Color(0xFFE88BB0),
  'rani pink': Color(0xFFD6337A),
  'royal blue': Color(0xFF3E63DD),
  'blue': Color(0xFF3E63DD),
  'navy': Color(0xFF1F2A55),
  'denim': Color(0xFF4A6FA5),
  'yellow': Color(0xFFF7D154),
  'mustard': Color(0xFFD9A52E),
  'orange': Color(0xFFF08C3A),
  'green': Color(0xFF46A758),
  'olive': Color(0xFF6B7A3A),
  'peacock green': Color(0xFF12A594),
  'teal': Color(0xFF12A594),
  'grey': Color(0xFF9B9A9E),
  'gray': Color(0xFF9B9A9E),
  'silver': Color(0xFFC0C0C8),
  'gold': Color(0xFFD4AF37),
  'purple': Color(0xFF8E4EC6),
  'lavender': Color(0xFFB9A3E3),
  'beige': Color(0xFFD9C7A8),
  'brown': Color(0xFF7B5236),
  'multicolour': Color(0xFFC77DFF),
};

Color swatchFor(String name) =>
    _swatches[name.trim().toLowerCase()] ?? const Color(0xFF6E6A78);

class FoodItem {
  final String id;
  final String name;
  final int daysLeft;
  final String category;
  /// When this item expires (date and time), if known.
  final DateTime? expiryDate;

  const FoodItem({
    required this.id,
    required this.name,
    required this.daysLeft,
    required this.category,
    this.expiryDate,
  });
}


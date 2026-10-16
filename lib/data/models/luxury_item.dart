enum LuxuryCategory {
  watch,
  vehicle,
  realEstate,
  exclusive;

  String get displayName {
    switch (this) {
      case LuxuryCategory.watch:
        return 'Luxusuhren';
      case LuxuryCategory.vehicle:
        return 'Sportwagen & Supercars';
      case LuxuryCategory.realEstate:
        return 'Immobilien & Penthouses';
      case LuxuryCategory.exclusive:
        return 'Jets, Yachten & Inseln';
    }
  }
}

class LuxuryItem {
  final String id;
  final String name;
  final LuxuryCategory category;
  final double price;
  final String icon;
  final String description;
  final int prestigePoints;
  int ownedCount;

  LuxuryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.icon,
    required this.description,
    required this.prestigePoints,
    this.ownedCount = 0,
  });

  bool get isOwned => ownedCount > 0;

  double get totalValue => ownedCount * price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'price': price,
        'icon': icon,
        'description': description,
        'prestigePoints': prestigePoints,
        'ownedCount': ownedCount,
      };

  factory LuxuryItem.fromJson(Map<String, dynamic> json) => LuxuryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: LuxuryCategory.values.byName(json['category'] as String),
        price: (json['price'] as num).toDouble(),
        icon: json['icon'] as String,
        description: json['description'] as String,
        prestigePoints: (json['prestigePoints'] as num).toInt(),
        ownedCount: (json['ownedCount'] as num?)?.toInt() ?? 0,
      );
}

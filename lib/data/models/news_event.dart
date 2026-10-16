import 'asset.dart';

class NewsEvent {
  final String id;
  final String headline;
  final String description;
  final AssetType? affectedType;
  final String? affectedSymbol;
  final double priceImpact;
  final DateTime timestamp;
  final String category;
  final bool isBreaking;

  NewsEvent({
    required this.id,
    required this.headline,
    required this.description,
    this.affectedType,
    this.affectedSymbol,
    required this.priceImpact,
    DateTime? timestamp,
    this.category = 'Börsen-News',
    this.isBreaking = true,
  }) : timestamp = timestamp ?? DateTime.now();

  String get title => headline;
  String get affectedAssetSymbol => affectedSymbol ?? '';
  double get priceImpactPercent => priceImpact;
  bool get isBullish => priceImpact >= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'headline': headline,
        'description': description,
        'affectedType': affectedType?.name,
        'affectedSymbol': affectedSymbol,
        'priceImpact': priceImpact,
        'timestamp': timestamp.toIso8601String(),
        'category': category,
        'isBreaking': isBreaking,
      };

  factory NewsEvent.fromJson(Map<String, dynamic> json) => NewsEvent(
        id: json['id'] as String,
        headline: json['headline'] as String? ?? json['title'] as String? ?? 'Börsenmeldung',
        description: json['description'] as String? ?? '',
        affectedType: json['affectedType'] != null
            ? AssetType.values.byName(json['affectedType'] as String)
            : null,
        affectedSymbol: json['affectedSymbol'] as String? ?? json['affectedAssetSymbol'] as String?,
        priceImpact: (json['priceImpact'] as num?)?.toDouble() ??
            (json['priceImpactPercent'] as num?)?.toDouble() ??
            0.0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        category: json['category'] as String? ?? 'Börsen-News',
        isBreaking: json['isBreaking'] as bool? ?? true,
      );
}

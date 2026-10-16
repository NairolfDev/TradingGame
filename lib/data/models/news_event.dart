import 'asset.dart';

class NewsEvent {
  final String id;
  final String headline;
  final String description;
  final AssetType? affectedType;
  final String? affectedSymbol;
  final double priceImpact; // z. B. +0.06 für +6% oder -0.08 für -8%
  final DateTime timestamp;
  final bool isBullish;

  NewsEvent({
    required this.id,
    required this.headline,
    required this.description,
    this.affectedType,
    this.affectedSymbol,
    required this.priceImpact,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        isBullish = priceImpact >= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'headline': headline,
        'description': description,
        'affectedType': affectedType?.name,
        'affectedSymbol': affectedSymbol,
        'priceImpact': priceImpact,
        'timestamp': timestamp.toIso8601String(),
      };

  factory NewsEvent.fromJson(Map<String, dynamic> json) => NewsEvent(
        id: json['id'] as String,
        headline: json['headline'] as String,
        description: json['description'] as String,
        affectedType: json['affectedType'] != null
            ? AssetType.values.byName(json['affectedType'] as String)
            : null,
        affectedSymbol: json['affectedSymbol'] as String?,
        priceImpact: (json['priceImpact'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

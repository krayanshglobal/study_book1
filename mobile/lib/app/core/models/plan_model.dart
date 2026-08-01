class PlanModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int durationDays;
  final List<String> features;
  final bool isActive;

  PlanModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.currency = 'inr',
    this.durationDays = 30,
    this.features = const [],
    this.isActive = true,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'inr',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      features: (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isActive: json['is_active'] != false,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogProductModel {
  final String id;
  final String name;
  final String description;
  final String categoryId;
  final List<String> images;
  final String brand;
  final bool isActive;
  final double basePrice;
  final double? offerPrice;
  final double rating;
  final int reviewCount;
  final Map<String, String> specifications;
  final List<String> highlights;
  final int warrantyMonths;
  final List<ProductVariation> variations;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.images,
    required this.brand,
    this.isActive = true,
    required this.basePrice,
    this.offerPrice,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.specifications,
    required this.highlights,
    required this.warrantyMonths,
    required this.variations,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CatalogProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CatalogProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      brand: data['brand'] ?? 'V-Guard',
      isActive: data['isActive'] ?? true,
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      offerPrice: data['offerPrice']?.toDouble(),
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      specifications: Map<String, String>.from(data['specifications'] ?? {}),
      highlights: List<String>.from(data['highlights'] ?? []),
      warrantyMonths: data['warrantyMonths'] ?? 12,
      variations: (data['variations'] as List<dynamic>?)
              ?.map((v) => ProductVariation.fromMap(v))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'images': images,
      'brand': brand,
      'isActive': isActive,
      'basePrice': basePrice,
      'offerPrice': offerPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'specifications': specifications,
      'highlights': highlights,
      'warrantyMonths': warrantyMonths,
      'variations': variations.map((v) => v.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CatalogProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    List<String>? images,
    String? brand,
    bool? isActive,
    double? basePrice,
    double? offerPrice,
    double? rating,
    int? reviewCount,
    Map<String, String>? specifications,
    List<String>? highlights,
    int? warrantyMonths,
    List<ProductVariation>? variations,
    DateTime? updatedAt,
  }) {
    return CatalogProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      images: images ?? this.images,
      brand: brand ?? this.brand,
      isActive: isActive ?? this.isActive,
      basePrice: basePrice ?? this.basePrice,
      offerPrice: offerPrice ?? this.offerPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      specifications: specifications ?? this.specifications,
      highlights: highlights ?? this.highlights,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      variations: variations ?? this.variations,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class ProductVariation {
  final String id;
  final Map<String, String> attributes; // e.g., {"Color": "Red", "Capacity": "5L"}
  final double price;
  final double? offerPrice;
  final int? warrantyMonths; // Overrides base warranty if set
  final String? sku;
  final String stockStatus; // 'in_stock', 'out_of_stock', 'pre_order'

  ProductVariation({
    required this.id,
    required this.attributes,
    required this.price,
    this.offerPrice,
    this.warrantyMonths,
    this.sku,
    this.stockStatus = 'in_stock',
  });

  factory ProductVariation.fromMap(Map<String, dynamic> map) {
    return ProductVariation(
      id: map['id'] ?? '',
      attributes: Map<String, String>.from(map['attributes'] ?? {}),
      price: (map['price'] ?? 0).toDouble(),
      offerPrice: map['offerPrice']?.toDouble(),
      warrantyMonths: map['warrantyMonths'],
      sku: map['sku'],
      stockStatus: map['stockStatus'] ?? 'in_stock',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attributes': attributes,
      'price': price,
      'offerPrice': offerPrice,
      'warrantyMonths': warrantyMonths,
      'sku': sku,
      'stockStatus': stockStatus,
    };
  }
}

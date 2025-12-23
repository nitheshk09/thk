import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_client.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;
  CartService._internal();

  final List<CartCourseItem> _items = [];
  bool _hydrated = false;

  List<CartCourseItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.price);
  }

  double get total => subtotal; // Can add taxes, discounts, etc. here

  Future<void> hydrate() async {
    if (_hydrated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      
      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> itemsList = jsonDecode(cartJson);
        _items.clear();
        _items.addAll(
          itemsList.map((json) => CartCourseItem.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _items.clear();
    }
    
    _hydrated = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  Future<bool> addItem({
    required CourseTopic topic,
    TopicDetail? detail,
  }) async {
    await hydrate();
    
    // Check if item already exists
    final existingIndex = _items.indexWhere((item) => item.id == topic.id);
    if (existingIndex >= 0) {
      // Item already in cart
      return false;
    }

    // Add new item
    final cartItem = CartCourseItem.fromTopic(topic, detail: detail);
    _items.add(cartItem);
    
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> removeItem(int topicId) async {
    await hydrate();
    
    _items.removeWhere((item) => item.id == topicId);
    
    await _persist();
    notifyListeners();
  }

  Future<void> clearCart() async {
    await hydrate();
    
    _items.clear();
    
    await _persist();
    notifyListeners();
  }

  bool contains(int topicId) {
    return _items.any((item) => item.id == topicId);
  }

  Future<void> checkout() async {
    // Here you would integrate with your payment system
    // For now, we'll just clear the cart after successful checkout
    await clearCart();
  }
}

class CartCourseItem {
  final int id;
  final String title;
  final String description;
  final String instructor;
  final String categoryName;
  final String difficulty;
  final double price;
  final double originalPrice;
  final double rating;
  final int ratingCount;
  final String thumbnailUrl;
  final bool isFree;
  final bool isDiscounted;
  final DateTime addedAt;

  CartCourseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    required this.categoryName,
    required this.difficulty,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.ratingCount,
    required this.thumbnailUrl,
    required this.isFree,
    required this.isDiscounted,
    required this.addedAt,
  });

  factory CartCourseItem.fromTopic(CourseTopic topic, {TopicDetail? detail}) {
    final sourceDetail = detail;
    final title = sourceDetail?.title ?? topic.title;
    final description = sourceDetail?.description ?? topic.description;
    final price = (sourceDetail?.price ?? topic.price).toDouble();
    final isFree = sourceDetail?.isFree ?? topic.isFree || price == 0;
    
    // Calculate original price (simulate discount)
    final originalPrice = price > 0 ? price * 1.2 : 0.0; // 20% discount simulation
    final isDiscounted = originalPrice > price && price > 0;

    return CartCourseItem(
      id: topic.id,
      title: title,
      description: description,
      instructor: topic.categoryName, // Using category as instructor for now
      categoryName: topic.categoryName,
      difficulty: topic.difficulty,
      price: price,
      originalPrice: originalPrice,
      rating: 4.5 + (topic.id % 5) * 0.1, // Generate fake rating based on ID
      ratingCount: 500 + (topic.id * 13) % 1000, // Generate fake rating count
      thumbnailUrl: sourceDetail?.thumbnailUrl ?? topic.thumbnailUrl,
      isFree: isFree,
      isDiscounted: isDiscounted,
      addedAt: DateTime.now(),
    );
  }

  factory CartCourseItem.fromJson(Map<String, dynamic> json) {
    return CartCourseItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      instructor: json['instructor'] as String,
      categoryName: json['categoryName'] as String,
      difficulty: json['difficulty'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      ratingCount: json['ratingCount'] as int,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      isFree: json['isFree'] as bool,
      isDiscounted: json['isDiscounted'] as bool,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructor': instructor,
      'categoryName': categoryName,
      'difficulty': difficulty,
      'price': price,
      'originalPrice': originalPrice,
      'rating': rating,
      'ratingCount': ratingCount,
      'thumbnailUrl': thumbnailUrl,
      'isFree': isFree,
      'isDiscounted': isDiscounted,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  // Convert back to CourseTopic if needed
  CourseTopic toCourseTopic() {
    return CourseTopic(
      id: id,
      title: title,
      description: description,
      categoryId: 0, // We don't store this in cart
      categoryName: categoryName,
      subcategoryId: null,
      subcategoryName: null,
      difficulty: difficulty,
      status: 'active',
      isFree: isFree,
      isFeatured: false,
      price: price,
      durationMinutes: 0, // We don't store this in cart
      thumbnailUrl: thumbnailUrl,
      isEnrolled: false,
      isPaid: false,
      paymentStatus: null,
    );
  }
}
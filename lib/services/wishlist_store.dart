import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class WishlistStore extends ChangeNotifier {
  WishlistStore._();

  static final WishlistStore instance = WishlistStore._();

  static const _storageKey = 'thinkcyber_wishlist_v1';

  bool _hydrated = false;
  final List<SavedCourse> _courses = [];

  List<SavedCourse> get courses => List.unmodifiable(_courses);

  Set<int> get ids => _courses.map((course) => course.id).toSet();

  bool contains(int topicId) => ids.contains(topicId);

  Future<void> hydrate() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _courses
            ..clear()
            ..addAll(
              decoded.whereType<Map<String, dynamic>>().map(
                SavedCourse.fromJson,
              ),
            );
        }
      } catch (_) {
        // If stored data is malformed, we ignore it and start fresh.
        _courses.clear();
      }
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<bool> toggleCourse({
    required CourseTopic summary,
    TopicDetail? detail,
  }) async {
    await hydrate();
    final index = _courses.indexWhere((course) => course.id == summary.id);
    if (index >= 0) {
      _courses.removeAt(index);
      await _persist();
      notifyListeners();
      return false;
    } else {
      final saved = SavedCourse.fromTopic(summary, detail: detail);
      _courses.insert(0, saved);
      await _persist();
      notifyListeners();
      return true;
    }
  }

  Future<void> remove(int topicId) async {
    await hydrate();
    _courses.removeWhere((course) => course.id == topicId);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await hydrate();
    _courses.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _courses.map((course) => course.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }
}

class SavedCourse {
  SavedCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    required this.difficulty,
    required this.status,
    required this.isFree,
    required this.isFeatured,
    required this.price,
    required this.durationMinutes,
    required this.thumbnailUrl,
    this.isEnrolled = false,
    this.isPaid = false,
    this.paymentStatus,
  });

  final int id;
  final String title;
  final String description;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String difficulty;
  final String status;
  final bool isFree;
  final bool isFeatured;
  final num price;
  final int durationMinutes;
  final String thumbnailUrl;
  final bool isEnrolled;
  final bool isPaid;
  final String? paymentStatus;

  factory SavedCourse.fromTopic(CourseTopic summary, {TopicDetail? detail}) {
    final source = detail;
    return SavedCourse(
      id: summary.id,
      title: source?.title ?? summary.title,
      description: source?.description ?? summary.description,
      categoryId: source?.categoryId ?? summary.categoryId,
      categoryName: source?.categoryName ?? summary.categoryName,
      subcategoryId: source?.subcategoryId ?? summary.subcategoryId,
      subcategoryName: source?.subcategoryName ?? summary.subcategoryName,
      difficulty: source?.difficulty ?? summary.difficulty,
      status: source?.status ?? summary.status,
      isFree: source?.isFree ?? summary.isFree,
      isFeatured: summary.isFeatured,
      price: source?.price ?? summary.price,
      durationMinutes: source?.durationMinutes ?? summary.durationMinutes,
      thumbnailUrl: source?.thumbnailUrl ?? summary.thumbnailUrl,
      isEnrolled: source?.isEnrolled ?? summary.isEnrolled,
      isPaid: source?.isPaid ?? summary.isPaid,
      paymentStatus: source?.paymentStatus ?? summary.paymentStatus,
    );
  }

  factory SavedCourse.fromJson(Map<String, dynamic> json) {
    return SavedCourse(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: json['categoryId'] as int? ?? 0,
      categoryName: json['categoryName'] as String? ?? '',
      subcategoryId: json['subcategoryId'] as int?,
      subcategoryName: json['subcategoryName'] as String?,
      difficulty: json['difficulty'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isFree: json['isFree'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      price: json['price'] as num? ?? 0,
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      isPaid: json['isPaid'] as bool? ?? false,
      paymentStatus: json['paymentStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'subcategoryId': subcategoryId,
    'subcategoryName': subcategoryName,
    'difficulty': difficulty,
    'status': status,
    'isFree': isFree,
    'isFeatured': isFeatured,
    'price': price,
    'durationMinutes': durationMinutes,
    'thumbnailUrl': thumbnailUrl,
    'isEnrolled': isEnrolled,
    'isPaid': isPaid,
    'paymentStatus': paymentStatus,
  };

  CourseTopic toCourseTopic() {
    return CourseTopic(
      id: id,
      title: title,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      difficulty: difficulty,
      status: status,
      isFree: isFree,
      isFeatured: isFeatured,
      price: price,
      durationMinutes: durationMinutes,
      thumbnailUrl: thumbnailUrl,
      isEnrolled: isEnrolled,
      isPaid: isPaid,
      paymentStatus: paymentStatus,
    );
  }
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics wrapper service
/// Provides methods for logging events, tracking screens, and setting user properties
class FirebaseAnalyticsService {
  // Singleton pattern
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;
  FirebaseAnalyticsService._internal();

  // Firebase Analytics instance
  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  /// Initialize Firebase Analytics
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      debugPrint('✅ Firebase Analytics initialized');
    } catch (e) {
      debugPrint('❌ Firebase Analytics initialization failed: $e');
    }
  }

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver? get observer => _observer;

  /// Log a custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('📊 Analytics Event: $name ${parameters ?? ""}');
    } catch (e) {
      debugPrint('❌ Failed to log event $name: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('📱 Screen View: $screenName');
    } catch (e) {
      debugPrint('❌ Failed to log screen view $screenName: $e');
    }
  }

  /// Set user ID
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics?.setUserId(id: userId);
      debugPrint('👤 User ID set: $userId');
    } catch (e) {
      debugPrint('❌ Failed to set user ID: $e');
    }
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
      debugPrint('🏷️ User Property: $name = $value');
    } catch (e) {
      debugPrint('❌ Failed to set user property $name: $e');
    }
  }

  // E-commerce events

  /// Log when a user views an item
  Future<void> logViewItem({
    required String itemId,
    required String itemName,
    String? itemCategory,
    double? price,
  }) async {
    await logEvent(
      name: 'view_item',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
        if (itemCategory != null) 'item_category': itemCategory,
        if (price != null) 'price': price,
        'currency': 'TRY',
      },
    );
  }

  /// Log when a user adds an item to cart
  Future<void> logAddToCart({
    required String itemId,
    required String itemName,
    String? itemCategory,
    required double price,
    required int quantity,
  }) async {
    await logEvent(
      name: 'add_to_cart',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
        if (itemCategory != null) 'item_category': itemCategory,
        'price': price,
        'quantity': quantity,
        'currency': 'TRY',
      },
    );
  }

  /// Log when a user removes an item from cart
  Future<void> logRemoveFromCart({
    required String itemId,
    required String itemName,
    required int quantity,
  }) async {
    await logEvent(
      name: 'remove_from_cart',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
        'quantity': quantity,
      },
    );
  }

  /// Log when a user begins checkout
  Future<void> logBeginCheckout({
    required double value,
    required int itemCount,
  }) async {
    await logEvent(
      name: 'begin_checkout',
      parameters: {
        'value': value,
        'currency': 'TRY',
        'item_count': itemCount,
      },
    );
  }

  /// Log when a purchase is completed
  Future<void> logPurchase({
    required String transactionId,
    required double value,
    required int itemCount,
    String? paymentType,
  }) async {
    await logEvent(
      name: 'purchase',
      parameters: {
        'transaction_id': transactionId,
        'value': value,
        'currency': 'TRY',
        'item_count': itemCount,
        if (paymentType != null) 'payment_type': paymentType,
      },
    );
  }

  /// Log when a user views an item list (category)
  Future<void> logViewItemList({
    required String itemListName,
    String? itemListId,
  }) async {
    await logEvent(
      name: 'view_item_list',
      parameters: {
        'item_list_name': itemListName,
        if (itemListId != null) 'item_list_id': itemListId,
      },
    );
  }

  /// Log search event
  Future<void> logSearch({
    required String searchTerm,
  }) async {
    await logEvent(
      name: 'search',
      parameters: {
        'search_term': searchTerm,
      },
    );
  }

  // Authentication events

  /// Log login event
  Future<void> logLogin({
    String method = 'email',
  }) async {
    await logEvent(
      name: 'login',
      parameters: {
        'method': method,
      },
    );
  }

  /// Log sign up event
  Future<void> logSignUp({
    String method = 'email',
  }) async {
    await logEvent(
      name: 'sign_up',
      parameters: {
        'method': method,
      },
    );
  }
}

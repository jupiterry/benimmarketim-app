import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Firebase Performance Monitoring wrapper service
/// Provides methods for custom traces and HTTP metrics
class FirebasePerformanceService {
  // Singleton pattern
  static final FirebasePerformanceService _instance =
      FirebasePerformanceService._internal();
  factory FirebasePerformanceService() => _instance;
  FirebasePerformanceService._internal();

  // Firebase Performance instance
  FirebasePerformance? _performance;

  // Active traces map
  final Map<String, Trace> _activeTraces = {};

  /// Initialize Firebase Performance
  Future<void> initialize() async {
    try {
      _performance = FirebasePerformance.instance;

      // Enable performance monitoring
      await _performance?.setPerformanceCollectionEnabled(true);

      debugPrint('✅ Firebase Performance Monitoring initialized');
    } catch (e) {
      debugPrint('❌ Firebase Performance initialization failed: $e');
    }
  }

  /// Start a custom trace
  Future<void> startTrace(String traceName) async {
    try {
      if (_activeTraces.containsKey(traceName)) {
        debugPrint('⚠️ Trace $traceName already running');
        return;
      }

      final trace = _performance?.newTrace(traceName);
      await trace?.start();

      if (trace != null) {
        _activeTraces[traceName] = trace;
        debugPrint('🚀 Started trace: $traceName');
      }
    } catch (e) {
      debugPrint('❌ Failed to start trace $traceName: $e');
    }
  }

  /// Stop a custom trace
  Future<void> stopTrace(String traceName) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        debugPrint('⚠️ Trace $traceName not found');
        return;
      }

      await trace.stop();
      _activeTraces.remove(traceName);
      debugPrint('✅ Stopped trace: $traceName');
    } catch (e) {
      debugPrint('❌ Failed to stop trace $traceName: $e');
    }
  }

  /// Set a metric value for a trace
  Future<void> setTraceMetric({
    required String traceName,
    required String metricName,
    required int value,
  }) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        debugPrint('⚠️ Trace $traceName not found');
        return;
      }

      trace.setMetric(metricName, value);
      debugPrint('📊 Trace metric: $traceName.$metricName = $value');
    } catch (e) {
      debugPrint('❌ Failed to set metric $metricName for trace $traceName: $e');
    }
  }

  /// Increment a metric for a trace
  Future<void> incrementTraceMetric({
    required String traceName,
    required String metricName,
    int incrementBy = 1,
  }) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        debugPrint('⚠️ Trace $traceName not found');
        return;
      }

      trace.incrementMetric(metricName, incrementBy);
      debugPrint(
          '📈 Incremented metric: $traceName.$metricName by $incrementBy');
    } catch (e) {
      debugPrint(
          '❌ Failed to increment metric $metricName for trace $traceName: $e');
    }
  }

  /// Set an attribute for a trace
  Future<void> setTraceAttribute({
    required String traceName,
    required String attributeName,
    required String value,
  }) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        debugPrint('⚠️ Trace $traceName not found');
        return;
      }

      trace.putAttribute(attributeName, value);
      debugPrint('🏷️ Trace attribute: $traceName.$attributeName = $value');
    } catch (e) {
      debugPrint(
          '❌ Failed to set attribute $attributeName for trace $traceName: $e');
    }
  }

  /// Create and track an HTTP metric
  Future<HttpMetric?> createHttpMetric({
    required String url,
    required HttpMethod method,
  }) async {
    try {
      final httpMetric = _performance?.newHttpMetric(url, method);
      debugPrint('🌐 Created HTTP metric: ${method.name} $url');
      return httpMetric;
    } catch (e) {
      debugPrint('❌ Failed to create HTTP metric: $e');
      return null;
    }
  }

  /// Helper method to measure async operations
  Future<T> measureAsync<T>({
    required String traceName,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) async {
    await startTrace(traceName);

    if (attributes != null) {
      for (final entry in attributes.entries) {
        await setTraceAttribute(
          traceName: traceName,
          attributeName: entry.key,
          value: entry.value,
        );
      }
    }

    try {
      final result = await operation();
      await stopTrace(traceName);
      return result;
    } catch (e) {
      await stopTrace(traceName);
      rethrow;
    }
  }

  /// Helper method to measure synchronous operations
  T measureSync<T>({
    required String traceName,
    required T Function() operation,
    Map<String, String>? attributes,
  }) {
    startTrace(traceName);

    if (attributes != null) {
      for (final entry in attributes.entries) {
        setTraceAttribute(
          traceName: traceName,
          attributeName: entry.key,
          value: entry.value,
        );
      }
    }

    try {
      final result = operation();
      stopTrace(traceName);
      return result;
    } catch (e) {
      stopTrace(traceName);
      rethrow;
    }
  }
}

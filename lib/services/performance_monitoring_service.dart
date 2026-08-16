import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode, kProfileMode;

/// Enhanced service for monitoring and logging performance metrics
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();

  factory PerformanceMonitoringService() => _instance;

  PerformanceMonitoringService._internal();

  // Configuration
  bool _enabled = kDebugMode || kProfileMode; // Enable by default in debug/profile
  bool _logToConsole = true;
  bool _collectMetrics = true;
  final Map<String, List<double>> _metricHistory = {};
  final Map<String, int> _counters = {};

  /// Enable or disable performance monitoring
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && _logToConsole) {
      developer.log('Performance monitoring disabled',
          name: 'PerformanceMonitoring');
    }
  }

  /// Set whether to log metrics to console
  void setLogToConsole(bool logToConsole) {
    _logToConsole = logToConsole;
  }

  /// Set whether to collect metrics for historical analysis
  void setCollectMetrics(bool collectMetrics) {
    _collectMetrics = collectMetrics;
  }

  /// Log the duration of an operation
  Future<void> logDuration(String operation, Future<void> Function() action) async {
    if (!_enabled) return await action();

    final stopwatch = Stopwatch()..start();
    try {
      await action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _recordMetric('$operation.duration', elapsedMs.toDouble(), 'ms');
      if (_logToConsole) {
        developer.log('Performance: $operation took ${elapsedMs}ms',
            name: 'PerformanceMonitoring');
      }
    }
  }

  /// Log the duration of an operation that returns a value
  Future<T> logDurationWithResult<T>(
      String operation, Future<T> Function() action) async {
    if (!_enabled) return await action();

    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      return result;
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _recordMetric('$operation.duration', elapsedMs.toDouble(), 'ms');
      if (_logToConsole) {
        developer.log('Performance: $operation took ${elapsedMs}ms',
            name: 'PerformanceMonitoring');
      }
    }
  }

  /// Log a metric value
  void logMetric(String metric, double value, {String unit = ''}) {
    if (!_enabled || !_collectMetrics) return;
    _recordMetric(metric, value, unit);
    if (_logToConsole) {
      developer.log('Metric: $metric = $value $unit',
          name: 'PerformanceMonitoring');
    }
  }

  /// Log a count metric
  void logCount(String metric, int count) {
    if (!_enabled || !_collectMetrics) return;
    _counters[metric] = (_counters[metric] ?? 0) + count;
    if (_logToConsole) {
      developer.log('Count: $metric = ${_counters[metric]}',
          name: 'PerformanceMonitoring');
    }
  }

  /// Log the duration of a synchronous operation that returns a value
  T logDurationSync<T>(String operation, T Function() action) {
    if (!_enabled) return action();

    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _recordMetric('$operation.duration', elapsedMs.toDouble(), 'ms');
      if (_logToConsole) {
        developer.log('Performance: $operation took ${elapsedMs}ms',
            name: 'PerformanceMonitoring');
      }
    }
  }

  /// Record a metric in internal history
  void _recordMetric(String metric, double value, String unit) {
    if (!_collectMetrics) return;
    if (!_metricHistory.containsKey(metric)) {
      _metricHistory[metric] = [];
    }
    _metricHistory[metric]!.add(value);

    // Keep only last 100 measurements to prevent memory leaks
    if (_metricHistory[metric]!.length > 100) {
      _metricHistory[metric]!.removeRange(0, _metricHistory[metric]!.length - 100);
    }
  }

  /// Get metric history for analysis
  Map<String, List<double>> getMetricHistory() {
    return Map.unmodifiable(_metricHistory);
  }

  /// Get counter values
  Map<String, int> getCounters() {
    return Map.unmodifiable(_counters);
  }

  /// Clear all collected metrics
  void clearMetrics() {
    _metricHistory.clear();
    _counters.clear();
  }

  /// Get average value for a metric
  double? getMetricAverage(String metric) {
    final values = _metricHistory[metric];
    if (values == null || values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Get latest value for a metric
  double? getMetricLatest(String metric) {
    final values = _metricHistory[metric];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  /// Log application startup time
  void logStartupTime(Duration startupTime) {
    logMetric('app.startup_time', startupTime.inMilliseconds.toDouble(), unit: 'ms');
  }

  /// Log frame rate (should be called from a frame callback)
  void logFrameRate(double fps) {
    logMetric('performance.fps', fps, unit: 'fps');

    // Warn if frame rate drops below threshold
    if (fps < 55 && _logToConsole) {
      developer.log('Warning: Frame rate dropped to ${fps.toStringAsFixed(1)} fps',
          name: 'PerformanceMonitoring');
    }
  }

  /// Log memory usage
  void logMemoryUsage() {
    if (!kReleaseMode) { // Only in debug/profile
      try {
        // Note: Detailed memory tracking requires devtools or platform-specific code
        // This is a placeholder for where memory monitoring would be integrated
        developer.log('Memory monitoring: Use DevTools for detailed memory analysis',
            name: 'PerformanceMonitoring');
      } catch (e) {
        // Ignore errors in memory logging
      }
    }
  }
}

/// Mixin to add enhanced performance monitoring to any class
mixin PerformanceMonitoringMixin {
  final PerformanceMonitoringService _perfService =
      PerformanceMonitoringService();

  /// Execute an action and log its duration
  Future<void> monitorOperation(
      String operation, Future<void> Function() action) async {
    return _perfService.logDuration(operation, action);
  }

  /// Execute an action that returns a value and log its duration
  Future<T> monitorOperationWithResult<T>(
      String operation, Future<T> Function() action) async {
    return _perfService.logDurationWithResult<T>(operation, action);
  }

  /// Execute a synchronous action and log its duration
  T monitorOperationSync<T>(
      String operation, T Function() action) {
    return _perfService.logDurationSync<T>(operation, action);
  }

  /// Log a metric value
  void monitorMetric(String metric, double value, {String unit = ''}) {
    _perfService.logMetric(metric, value, unit: unit);
  }

  /// Log a count metric
  void monitorCount(String metric, int count) {
    _perfService.logCount(metric, count);
  }
}
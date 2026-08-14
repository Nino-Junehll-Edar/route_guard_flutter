import 'dart:async';
import 'dart:developer' as developer;

/// Service for monitoring and logging performance metrics
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();

  factory PerformanceMonitoringService() => _instance;

  PerformanceMonitoringService._internal();

  /// Log the duration of an operation
  Future<void> logDuration(String operation, Future<void> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      await action();
    } finally {
      stopwatch.stop();
      developer.log('Performance: $operation took ${stopwatch.elapsedMilliseconds}ms',
          name: 'PerformanceMonitoring');
    }
  }

  /// Log the duration of an operation that returns a value
  Future<T> logDurationWithResult<T>(
      String operation, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      return result;
    } finally {
      stopwatch.stop();
      developer.log('Performance: $operation took ${stopwatch.elapsedMilliseconds}ms',
          name: 'PerformanceMonitoring');
    }
  }

  /// Log a metric value
  void logMetric(String metric, double value, {String unit = ''}) {
    developer.log(
        'Metric: $metric = $value $unit',
        name: 'PerformanceMonitoring');
  }

  /// Log a count metric
  void logCount(String metric, int count) {
    developer.log('Count: $metric = $count', name: 'PerformanceMonitoring');
  }

  /// Log the duration of a synchronous operation that returns a value
  T logDurationSync<T>(String operation, T Function() action) {
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      developer.log('Performance: $operation took ${stopwatch.elapsedMilliseconds}ms',
          name: 'PerformanceMonitoring');
    }
  }
}

/// Mixin to add performance monitoring to any class
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
}
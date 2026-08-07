import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight frame telemetry for debug/profile builds.
///
/// It does not run in release mode. Every 120 frames it reports average and
/// p95 build/raster duration, plus the number of frames above the 16.67 ms
/// budget used for a 60 Hz display.
abstract final class PerformanceMonitor {
  static final List<FrameTiming> _window = <FrameTiming>[];
  static bool _started = false;

  static void start() {
    if (_started || kReleaseMode) {
      return;
    }
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    _window.addAll(timings);
    if (_window.length < 120) {
      return;
    }

    final sample = List<FrameTiming>.of(_window);
    _window.clear();
    final build = sample
        .map((timing) => timing.buildDuration.inMicroseconds / 1000)
        .toList(growable: false);
    final raster = sample
        .map((timing) => timing.rasterDuration.inMicroseconds / 1000)
        .toList(growable: false);
    final total = sample
        .map((timing) => timing.totalSpan.inMicroseconds / 1000)
        .toList(growable: false);

    final overBudget = total.where((duration) => duration > 16.67).length;
    debugPrint(
      '[PERF] frames=${sample.length} '
      'build_avg=${_average(build).toStringAsFixed(2)}ms '
      'build_p95=${_percentile(build, 0.95).toStringAsFixed(2)}ms '
      'raster_avg=${_average(raster).toStringAsFixed(2)}ms '
      'raster_p95=${_percentile(raster, 0.95).toStringAsFixed(2)}ms '
      'over_16ms=$overBudget',
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<double>.of(values)..sort();
    final index = math.min(
      sorted.length - 1,
      (sorted.length * percentile).ceil() - 1,
    );
    return sorted[index];
  }
}

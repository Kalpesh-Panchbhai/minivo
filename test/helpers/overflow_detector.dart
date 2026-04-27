import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class OverflowDetector {
  static final List<String> _errors = [];
  static FlutterExceptionHandler? _originalHandler;

  static void start() {
    _errors.clear();
    _originalHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed') || message.contains('overflow')) {
        _errors.add(message);
      }
      _originalHandler?.call(details);
    };
  }

  static void stop() {
    FlutterError.onError = _originalHandler;
  }

  static void expectNoOverflow({String context = ''}) {
    if (_errors.isNotEmpty) {
      final msg = _errors.join('\n---\n');
      _errors.clear();
      fail('Overflow detected${context.isNotEmpty ? ' on $context' : ''}: $msg');
    }
  }

  static void reset() {
    _errors.clear();
  }
}

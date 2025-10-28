import 'package:mason_logger/mason_logger.dart' as mason;

/// Simple logger wrapper
class Logger {
  final mason.Logger _logger;

  Logger() : _logger = mason.Logger();

  void info(String message) => _logger.info(message);
  void success(String message) => _logger.success(message);
  void warning(String message) => _logger.warn(message);
  void error(String message) => _logger.err(message);
  void detail(String message) => _logger.detail(message);
  void hint(String message) => _logger.info('💡 $message');

  mason.Progress progress(String message) => _logger.progress(message);
}

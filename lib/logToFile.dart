import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final logger = Logger(
  printer: PrettyPrinter(),
);

Future<void> logToFile(String message) async {
  try {
    // Get the application documents directory
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_logs.txt');

    // Check if the file exists; if not, create it
    if (!await file.exists()) {
      await file.create();
    }
    // Append the message to the log file with a timestamp
    final timestamp = DateTime.now().toIso8601String();
    await file.writeAsString("[$timestamp] $message\n", mode: FileMode.append);

    // Optional: Also log to the console
    logger.i(message);
  } catch (e) {
    // Handle any file-related errors
    logger.e("Failed to write log to file: $e");
  }
}

void logMessage(String message) {
  logToFile(message);
  logger.i(message); // Log to console
}

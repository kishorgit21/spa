import 'dart:convert';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io'; // Required to check platform
import 'package:spa/logToFile.dart';

class Deviceinfo {
  static Future<String?> getDeviceId() async {
    try {
      var deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        // iOS-specific code
        var iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor; // Unique ID on iOS
      } else if (Platform.isAndroid) {
        // Android-specific code
        var androidDeviceInfo = await deviceInfo.androidInfo;
        return const AndroidId().getId(); // Unique ID on Android
      }
      return null; // Return null if neither Android nor iOS
    } catch (e) {
      logMessage("Failed to get device ID:: $e");
    }

    return null; // Return an empty string if unable to fetch the ID
  }
}

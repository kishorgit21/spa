import 'dart:convert';
import 'package:spa/SPAUserModel.dart';
import 'package:http/http.dart' as http;
import 'package:spa/logToFile.dart';
import 'config.dart';

class ApiServices {
  // With Model
  Future<SPAUserModel?> saveSPAUserModel(SPAUserModel model) async {
    try {
      // Convert model to JSON
      //logMessage("Attempting to save SPAUserModel: ${model.toJson()}");

      var body = jsonEncode(model.toJson());

      var response = await http.post(
        Uri.parse(Config.spaBaseUrl + Config.spaUserEndPoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
        },
        body: body,
      );

      //logMessage("Received response with status code: ${response.statusCode}");
      //logMessage("Response body: ${response.body}");

      if (response.statusCode == 200) {
        // Parse the response body into JSON
        var jsonResponse = json.decode(response.body);
        logMessage("User saved successfully");
        //logMessage("User saved successfully: ${jsonResponse.toJson()}");
        // Convert JSON to SPAUserModel
        return SPAUserModel.fromJson(jsonResponse);
      } else {
        logMessage(
            "Failed to save user. Status code: ${response.statusCode}, body: ${response.body}");
        return null;
      }
    } catch (error) {
      logMessage("Network error occurred while saving user: $error");
      return null;
    }
  }

  Future<SPAUserModel?> fetchSPAUser(String? deviceid) async {
    try {
      if (deviceid == null || deviceid.isEmpty) {
        throw Exception("Device ID cannot be null or empty");
      }
      var url = Uri.parse(Config.spaBaseUrl + Config.spaUserEndPoint)
          .replace(queryParameters: {"deviceid": deviceid});

      var response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        logMessage("User fetched successfully");
        return SPAUserModel.fromJson(jsonResponse['data']);
      } else {
        logMessage(
            "Failed to fetch user. Status code: ${response.statusCode}, body: ${response.body}");
        return null;
      }
    } catch (error) {
      logMessage("Error fetching user: $error");
      return null;
    }
  }
}

import 'dart:convert';
import 'package:spa/SPAUserModel.dart';
import 'package:http/http.dart' as http;
import 'package:spa/logToFile.dart';

class ApiServices {
  // With Model
  Future<SPAUserModel?> saveSPAUserModel(SPAUserModel model) async {
    try {
      // Convert model to JSON
      //logMessage("Attempting to save SPAUserModel: ${model.toJson()}");

      var body = jsonEncode(model.toJson());

      var response = await http.post(
        Uri.parse("https://aaryainfosolutions.com/spa/SPAUser.php"),
        headers: {
          'Content-Type': 'application/json',
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
}

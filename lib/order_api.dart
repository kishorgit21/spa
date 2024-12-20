import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spa/logToFile.dart';
import 'config.dart';

class OrderAPI {
  // Method to generate Order ID
  static Future<String> generateOrderID(int amount) async {
    try {
      final headers = await Config.getHeaders();

      // Make the HTTP POST request
      var response = await http.post(
        Uri.parse(Config.orderEndpoint),
        headers: headers,
        body: jsonEncode({'amount': amount, 'currency': 'INR'}),
      );

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['id'];
      } else {
        logMessage('Error: ${response.statusCode} - ${response.body}');
        return ''; // Return empty ID on failure
      }
    } catch (e) {
      logMessage('Exception occurred while generating Order ID: $e');
      return ''; // Return empty ID on exception
    }
  }

  // Razorpay Options Generator
  static Future<Map<String, dynamic>> getRazorpayOptions(String orderId) async {
    return {
      'key': Config.razorpayApiKey,
      'order_id': orderId,
      'name': 'SPA',
      'description': 'Registration Fee',
      'timeout': 300,
      'prefill': prefillDetails,
      'theme': {
        'color': '#F37254',
      },
    };
  }

  static Map<String, String> prefillDetails = {
    'contact': Config.contact,
    'email': Config.email,
  };

  static int amount = Config.amount;
}

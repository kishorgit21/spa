import 'dart:convert';

import 'package:http/http.dart' as http;

class OrderAPI {
  static String orderIDUrl = 'https://api.razorpay.com/v1/orders';

  static Future<Map<String, String>> getHeader() async {
    return {
      'Content-Type': 'application/json',
      'Authorization':
          'Basic ${base64Encode(utf8.encode('rzp_test_dwzzI6TiwTr1yA:6uwI1xODLf4d41tKzeu9djso'))}'
    };
  }

  static Future<String> generateOrderID(int amount) async {
    final header = await getHeader();
    var response = await http.post(Uri.parse(orderIDUrl),
        headers: header,
        body: jsonEncode({'amount': amount, 'currency': 'INR'}));
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['id'];
    } else {
      return '';
    }
  }
}

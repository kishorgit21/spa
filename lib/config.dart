import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class Config {
  static String get razorpayApiKey => dotenv.env['RAZORPAY_API_KEY'] ?? '';
  static String get razorpayApiSecret =>
      dotenv.env['RAZORPAY_API_SECRET'] ?? '';
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  static String get orderEndpoint => '$baseUrl/orders';
  static String get contact => dotenv.env['CONTACT'] ?? '';
  static String get email => dotenv.env['EMAIL'] ?? '';
  static int get amount => int.tryParse(dotenv.env['AMOUNT'] ?? '0') ?? 0;

  static Map<String, String> getHeaders() {
    final credentials = '$razorpayApiKey:$razorpayApiSecret';
    final encodedCredentials = base64Encode(utf8.encode(credentials));
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $encodedCredentials',
    };
  }
}

import 'package:show_app_frontend/services/auth_service.dart';

class ApiConfig {
  static const String baseUrl = 'http://localhost:5000';  // Pour le mode web
  
  
  static Future<Map<String, String>> getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
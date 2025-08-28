import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class StreamTokenService {
  static const String _tokenUrl = 'https://stream-token-beta.vercel.app/token';

  static Future<String> generateUserToken({required String userId}) async {
    try {
      log('Generating token for user: $userId');

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'] as String?;

        if (token != null && token.isNotEmpty) {
          log('Token generated successfully');
          return token;
        } else {
          throw Exception('Invalid token received from server');
        }
      } else {
        log(
          'Token generation failed: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to generate token: ${response.statusCode}');
      }
    } catch (e) {
      log('Error generating Stream token: $e');
      rethrow;
    }
  }
}

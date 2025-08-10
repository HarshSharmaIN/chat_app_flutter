import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StreamTokenService {
  static String generateUserToken({
    required String userId,
    String? apiSecret,
  }) {
    try {
      final secret = apiSecret ?? dotenv.env['STREAM_SECRET'] ?? '';
      if (secret.isEmpty) {
        throw Exception('Stream API secret not found');
      }

      final header = {
        'alg': 'HS256',
        'typ': 'JWT',
      };

      final payload = {
        'user_id': userId,
        'iss': 'stream-video',
        'sub': 'user/$userId',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      };

      final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
      final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
      
      final signature = _generateSignature('$encodedHeader.$encodedPayload', secret);
      
      return '$encodedHeader.$encodedPayload.$signature';
    } catch (e) {
      log('Error generating Stream token: $e');
      rethrow;
    }
  }

  static String _generateSignature(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64Url.encode(digest.bytes);
  }
}
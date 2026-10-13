import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';

enum ApiFailure { response, connection, timeout, invalidResponse }

class ApiException implements Exception {
  final String message;
  final int? status;
  final ApiFailure failure;
  const ApiException(
    this.message, [
    this.status,
    this.failure = ApiFailure.response,
  ]);
  @override
  String toString() => message;
}

class ApiService {
  final http.Client client;
  final FlutterSecureStorage storage;
  String? token;
  void Function()? onUnauthorized;
  ApiService({http.Client? client, FlutterSecureStorage? storage})
    : client = client ?? http.Client(),
      storage = storage ?? const FlutterSecureStorage();
  Future<void> restore() async =>
      token = await storage.read(key: 'timeguard_token');
  Future<void> saveToken(String value) async {
    await storage.write(key: 'timeguard_token', value: value);
    token = value;
  }

  Future<void> clearToken() async {
    token = null;
    await storage.delete(key: 'timeguard_token');
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _request('GET', path, query: query);
  Future<dynamic> post(String path, [Json body = const {}]) =>
      _request('POST', path, body: body);
  Future<dynamic> _request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl
          : '${ApiConfig.baseUrl}/';
      final uri = Uri.parse('$base$path').replace(queryParameters: query);
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response =
          await (method == 'GET'
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(ApiConfig.timeout);
      if (response.statusCode == 401 && token != null) {
        await clearToken();
        onUnauthorized?.call();
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(
          'ข้อมูลตอบกลับจากเซิร์ฟเวอร์ไม่ถูกต้อง',
          response.statusCode,
          ApiFailure.invalidResponse,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      if (response.statusCode >= 400 || decoded['success'] != true) {
        throw ApiException(
          decoded['message'] ?? 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
          response.statusCode,
        );
      }
      return decoded['data'];
    } on TimeoutException {
      throw const ApiException(
        'เซิร์ฟเวอร์ตอบสนองช้า กรุณาลองใหม่',
        null,
        ApiFailure.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ ตรวจสอบเครือข่ายและ URL',
        null,
        ApiFailure.connection,
      );
    } on FormatException {
      throw const ApiException(
        'ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง ตรวจสอบการติดตั้ง PHP API',
        null,
        ApiFailure.invalidResponse,
      );
    }
  }
}

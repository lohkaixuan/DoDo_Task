// lib/apis.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'apimodel.dart';
import 'dioclient.dart';

// Always hand a Map<String, dynamic> to your models
Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String && data.isNotEmpty) return jsonDecode(data) as Map<String, dynamic>;
  return <String, dynamic>{}; // fallback to empty map
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final DioClient _dioClient;
  ApiService(this._dioClient);

  // ---------- AUTH ----------
  Future<LoginResponse> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      print('login -> res.data runtimeType: ${response.data.runtimeType}');
      final body = _asMap(response.data);
      return LoginResponse.fromJson(body);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode,
        e.response?.data?.toString() ?? e.message ?? 'Something went wrong',
      );
    }
  }

  Future<LoginResponse> loginWithToken(String token) async {
    try {
      final response = await _dioClient.dio.post('/auth/login', data: {
        'token': token,
      });
      print('loginWithToken -> res.data runtimeType: ${response.data.runtimeType}');
      final body = _asMap(response.data);
      return LoginResponse.fromJson(body);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode,
        e.response?.data?.toString() ?? e.message ?? 'Something went wrong',
      );
    }
  }

  Future<RegisterResponse> register(String email, String password, String displayName) async {
    print('ApiService.register called with email: $email, password: $password');
    try {
      final response = await _dioClient.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      });
      print('register -> res.data runtimeType: ${response.data.runtimeType}');
      final body = _asMap(response.data);
      return RegisterResponse.fromJson(body);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode,
        e.response?.data?.toString() ?? e.message ?? 'Something went wrong',
      );
    }
  }
}

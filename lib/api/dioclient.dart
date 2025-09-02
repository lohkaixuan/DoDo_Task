import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class DioClient {
  final Dio _dio;

  DioClient({String? overrideBaseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: overrideBaseUrl ?? _resolveBaseUrl(),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.next(options),
      onError: (e, handler) => handler.next(e),
    ));
  }

  static String _resolveBaseUrl() {
    // 1) If you pass it at run-time, use that
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // 2) Dev defaults per platform
    if (kIsWeb) return 'http://127.0.0.1:8000';      // Flutter Web → your PC
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator → host
    if (!kIsWeb && Platform.isIOS) return 'http://127.0.0.1:8000';    // iOS simulator

    // 3) Physical device on same Wi-Fi (CHANGE THIS to your PC/Laptop IP)
    return 'http://192.168.0.217:8000';
  }

  Dio get dio => _dio;
}

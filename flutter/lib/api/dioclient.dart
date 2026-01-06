// ==================================================
// Program Name   : dioclient.dart
// Purpose        : Configure and manage Dio HTTP client settings, including base URL, timeout, interceptors, and headers.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 25 August 2025
// Last Modified  : 12 December 2025
// ==================================================

import 'package:dio/dio.dart';
import 'package:v3/storage/authStorage.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: "https://dodo-task-1.onrender.com",
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 50),
        responseType: ResponseType.json,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ✅ Add token automatically for EVERY request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthStorage.readToken();
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) {
          // optional debug
          // ignore: avoid_print
          print("Dio Error: ${e.response?.statusCode} ${e.response?.data}");
          return handler.next(e);
        },
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:v3/storage/authStorage.dart';

class DioClient {
  final Dio _dio;

  DioClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "https://dodo-task-1.onrender.com".trim(), // ✅ Change to your API URL
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            responseType: ResponseType.json, 
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 👇👇👇 必须把这段加回来！这是身份证明！ 👇👇👇
        try {
          final token = await AuthStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token'; // 👈 关键！
          }
        } catch (e) {
          print("Error reading token: $e");
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print("Dio Error: ${e.message}"); // 打印一下错误方便调试
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}

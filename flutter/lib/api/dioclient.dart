import 'package:dio/dio.dart';
import 'package:get/get.dart';

class DioClient {
  final Dio _dio;

  DioClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "https://dodo-task-1.onrender.com".trim(), // ✅ Change to your API URL
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            responseType: ResponseType.json, 
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Token handling removed for now
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

import 'package:dio/dio.dart';
import 'package:get/get.dart';

class DioClient {
  final Dio _dio;

  DioClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: "https://997a581ce246.ngrok-free.app".trim(), // ✅ Change to your API URL
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
        // if (e.response?.statusCode == 401) {
        //   // 🔹 Redirect to login if unauthorized
        //   Get.offAllNamed('/login');
        // }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}

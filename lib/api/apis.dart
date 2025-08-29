
import 'package:dio/dio.dart';
import 'apimodel.dart';
import 'dioclient.dart';


class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() {
    return 'ApiException: $statusCode - $message';
  }
}

class ApiService {
  final DioClient _dioClient;
  //String? _token;

  ApiService(this._dioClient);

  /// 🔹 Initialize the token asynchronously
  // Future<void> initialize() async {
  //   _token = await Storage().getAuthToken();
  // }

  /// 🔹 Authentication APIs
  Future<ApiResponse> login(String email, String password) async {
    try {
      // Use the dio alias here to avoid confusion with your ApiResponse
      var response = await _dioClient.dio.post(
        '/login',
        data: {"email": email, "password": password},
      );
      print("login api $response");
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException(e.response?.statusCode,
          e.response?.data['message'] ?? 'Something went wrong');
    }
  }
}
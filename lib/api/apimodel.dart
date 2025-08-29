
class ApiResponse {
  final String status;
  final String message;
  final dynamic data; // or make a typed model

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'], // can be Map/List/String/null
    );
  }
}
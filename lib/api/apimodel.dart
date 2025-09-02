
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

class TaskDto {
  final String id;
  final String title;
  final bool completed;

  /// 1..5 (5 = highest)
  final int priority;
  /// 1..5 (5 = most important)
  final int importance;

  /// 'study' | 'personal' | 'family'
  final String mode;

  final int? estimateMins;
  final DateTime? due;
  final String? notes;

  TaskDto({
    required this.id,
    required this.title,
    this.completed = false,
    this.priority = 3,
    this.importance = 3,
    this.mode = 'study',
    this.estimateMins,
    this.due,
    this.notes,
  });

  TaskDto copyWith({
    String? title,
    bool? completed,
    int? priority,
    int? importance,
    String? mode,
    int? estimateMins,
    DateTime? due,
    String? notes,
  }) {
    return TaskDto(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      importance: importance ?? this.importance,
      mode: mode ?? this.mode,
      estimateMins: estimateMins ?? this.estimateMins,
      due: due ?? this.due,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'priority': priority,
        'importance': importance,
        'mode': mode,
        'estimateMins': estimateMins,
        'due': due?.toIso8601String(),
        'notes': notes,
      };

  factory TaskDto.fromJson(Map<String, dynamic> json) => TaskDto(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        completed: json['completed'] == true,
        priority: (json['priority'] ?? 3) as int,
        importance: (json['importance'] ?? 3) as int,
        mode: (json['mode'] ?? 'study').toString(),
        estimateMins: json['estimateMins'],
        due: json['due'] != null ? DateTime.parse(json['due']) : null,
        notes: json['notes'],
      );
}


class registerResponse {
  final String status;
  final String message;
  final dynamic data; // or make a typed model
  final String? email;
  final String? id;
  registerResponse({
    required this.status,
    required this.message,
    this.data,
    this.email,
    this.id,
  });

  factory registerResponse.fromJson(Map<String, dynamic> json) {
    return registerResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'], // can be Map/List/String/null
      email: json['email']?.toString(),
      id: json['id']?.toString(),
    );
  }
}


/*
// lib/network/api_response.dart
import 'dart:convert';

enum ApiStatus { success, error, unknown }

ApiStatus _statusFrom(dynamic v) {
  final s = (v ?? '').toString().toLowerCase();
  if (s == 'success' || s == 'ok') return ApiStatus.success;
  if (s == 'error' || s == 'fail' || s == 'failed') return ApiStatus.error;
  return ApiStatus.unknown;
}

/// Generic envelope for APIs that return { status, message, data, ... }
class ApiEnvelope<T> {
  final ApiStatus status;
  final String? message;
  final T? data;
  final Map<String, dynamic>? meta; // optional extras (id/email/etc.)

  ApiEnvelope({
    required this.status,
    this.message,
    this.data,
    this.meta,
  });

  /// Flexible: if the server doesn't use an envelope, we treat the entire json as `data`.
  static ApiEnvelope<T> fromJson<T>(
    dynamic json, {
    T Function(Object? value)? parseData,
  }) {
    if (json is Map<String, dynamic>) {
      final hasEnvelope = json.containsKey('status') || json.containsKey('message') || json.containsKey('data');
      if (hasEnvelope) {
        final status = _statusFrom(json['status']);
        final msg = json['message']?.toString();
        final rawData = json['data'];
        final T? data = parseData != null ? parseData(rawData) : (rawData as T?);
        final meta = Map<String, dynamic>.from(json)..remove('status')..remove('message')..remove('data');
        return ApiEnvelope<T>(status: status, message: msg, data: data, meta: meta.isEmpty ? null : meta);
      }
    }
    // Not an envelope → wrap as success with whole json as data
    final T? data = parseData != null ? parseData(json) : (json as T?);
    return ApiEnvelope<T>(status: ApiStatus.success, data: data, message: null, meta: null);
  }
}

/// Unified failure info
class ApiError {
  final int? statusCode;
  final String message;
  final dynamic details; // backend error body if any

  ApiError({this.statusCode, required this.message, this.details});

  @override
  String toString() => 'ApiError($statusCode): $message';
}

/// Success/Failure wrapper you can use in UI without try/catch everywhere
abstract class ApiResult<T> {
  const ApiResult();
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiError error) failure,
  });
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
  @override
  R when<R>({required R Function(T) success, required R Function(ApiError) failure}) => success(data);
}

class ApiFailure<T> extends ApiResult<T> {
  final ApiError error;
  const ApiFailure(this.error);
  @override
  R when<R>({required R Function(T) success, required R Function(ApiError) failure}) => failure(error);
}

*/
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/storage/authStorage.dart';
import '../api/dioclient.dart';
import '../controller/petController.dart';
import '../controller/authController.dart'; // if you have it

class PetChatController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  // (optional) try to get a real user id
  final AuthController? _auth =
      Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
  final PetController? _pet =
      Get.isRegistered<PetController>() ? Get.find<PetController>() : null;

  final messages = <ChatMessage>[].obs;
  final isSending = false.obs;

  final input = TextEditingController();
  final scroll = ScrollController();

  @override
  void onClose() {
    input.dispose();
    scroll.dispose();
    super.onClose();
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || isSending.value) return;

    input.clear();
    _append(ChatMessage.user(text));

    // pick a user id (fallback keeps API happy for now)
    final userId =AuthStorage.readUserId() as String;

    isSending.value = true;
    try {
      final res = await _dio.dio.post(
        '/ai/pet/chat',
        data: {
          'user_id': userId,
          'text': text,
          'use_inworld': true, // or false if you want to force local model
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final reply = _extractReply(res.data);
      _append(ChatMessage.ai(reply));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;

      // Show a helpful error message instead of generic text
      final msg = _friendlyError(code, body, e.message);
      _append(ChatMessage.system(msg));

      debugPrint('[pet-chat] error $code: ${e.message}\nBODY: $body');
    } catch (e) {
      _append(ChatMessage.system('Unexpected error: $e'));
      debugPrint('[pet-chat] unexpected: $e');
    } finally {
      isSending.value = false;
    }
  }

  String _friendlyError(int? code, dynamic body, String? message) {
    // 422 from FastAPI → validation failure (wrong body keys, etc.)
    if (code == 422) return 'Hmm, request format invalid (422). I fixed the body—try again.';
    if (code != null) {
      final details = (body is Map && body['detail'] != null) ? body['detail'].toString() : message;
      return 'Error $code: ${details ?? 'server error'}';
    }
    return 'Network error: ${message ?? 'check connection'}';
  }

  String _extractReply(dynamic data) {
    // supports {data:{reply}}, {reply}, or {message}
    if (data is Map) {
      final d = data['data'];
      if (d is Map && d['reply'] != null) return d['reply'].toString();
      if (data['reply'] != null) return data['reply'].toString();
      if (data['message'] is String) return data['message'] as String;
    }
    return data?.toString() ?? '…';
  }

  void _append(ChatMessage m) {
    messages.add(m);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool fromUser;
  final DateTime ts;
  ChatMessage(this.id, this.text, this.fromUser, this.ts);
  factory ChatMessage.user(String t) =>
      ChatMessage('u_${DateTime.now().microsecondsSinceEpoch}', t, true, DateTime.now());
  factory ChatMessage.ai(String t) =>
      ChatMessage('a_${DateTime.now().microsecondsSinceEpoch}', t, false, DateTime.now());
  factory ChatMessage.system(String t) =>
      ChatMessage('s_${DateTime.now().microsecondsSinceEpoch}', t, false, DateTime.now());
}

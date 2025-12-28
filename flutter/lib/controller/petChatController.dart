import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/api/dioclient.dart';
import 'package:v3/storage/authStorage.dart';
import 'package:v3/services/tts_service.dart';

class PetChatController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

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

    final userId = await _safeUserId();

    isSending.value = true;
    try {
      final res = await _dio.dio.post(
        '/ai/pet/chat',
        data: {
          'user_id': userId,
          'text': text,
        },
      );

      String reply = '';
      final data = res.data;
      if (data is Map) {
        reply = (data['data'] is Map)
            ? (data['data']['reply']?.toString() ?? '')
            : '';
        reply = reply.isNotEmpty ? reply : (data['reply']?.toString() ?? '');
      }

      if (reply.trim().isEmpty) {
        _append(ChatMessage.system("Pet got shy 🦈… no reply received."));
        return;
      }

      _append(ChatMessage.ai(reply));
      await TtsService.instance.speak(reply);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
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

  Future<String> _safeUserId() async {
    try {
      final v = await AuthStorage.readUserId();
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}

    return 'guest-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _friendlyError(int? code, dynamic body, String? message) {
    if (code == 422) return 'Request format invalid (422). Please try again.';
    if (code != null) {
      final details =
          (body is Map && body['detail'] != null) ? body['detail'].toString() : message;
      return 'Error $code: ${details ?? 'server error'}';
    }
    return 'Network error: ${message ?? 'check connection'}';
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

  factory ChatMessage.user(String t) => ChatMessage(
        'u_${DateTime.now().microsecondsSinceEpoch}',
        t,
        true,
        DateTime.now(),
      );

  factory ChatMessage.ai(String t) => ChatMessage(
        'a_${DateTime.now().microsecondsSinceEpoch}',
        t,
        false,
        DateTime.now(),
      );

  factory ChatMessage.system(String t) => ChatMessage(
        's_${DateTime.now().microsecondsSinceEpoch}',
        t,
        false,
        DateTime.now(),
      );
}

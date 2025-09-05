import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/storage/authStorage.dart';

import '../api/dioclient.dart';
import '../controller/petController.dart';
import '../controller/authController.dart';

class PetChatController extends GetxController {
  final DioClient _dio = Get.find<DioClient>();

  /*final AuthController? _auth =
      Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
  final PetController? _pet =
      Get.isRegistered<PetController>() ? Get.find<PetController>() : null;
  */

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

    // 先清空输入框 & 先把“自己发的消息”加入（UI 及时反馈）
    input.clear();
    _append(ChatMessage.user(text));

    // ✅ 正确地 await 读取 userId，并处理 null/空串
    String userId = await _safeUserId();

    isSending.value = true;
    try {
      final res = await _dio.dio.post(
        '/ai/pet/chat',
        data: {
          'user_id': userId,
          'text': text,
          'use_inworld': false, // 需要的话自己切换 true/false
        },
        //later edit!
        //options: Options(
        //  headers: {
        //    'Content-Type': 'application/json',
        //  },
        //),
      );

      final reply = _extractReply(res.data);
      _append(ChatMessage.ai(reply));
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

  /// ✅ 统一获取 userId 的地方：优先读本地存储；如果为空再退化到 auth；最后兜底 guest-*
  Future<String> _safeUserId() async {
    try {
      final v = await AuthStorage.readUserId(); // <-- 这里是 Future<String?>
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    } catch (_) {}
    // 从 AuthController 里拿（如果有的话）
    //final fromAuth = _auth?.currentUserId;
    //if (fromAuth != null && fromAuth.toString().trim().isNotEmpty) {
    //  return fromAuth.toString().trim();
    //}
    // 最后兜底：给一个 guest-id，避免后端 422
    return 'guest-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _friendlyError(int? code, dynamic body, String? message) {
    if (code == 422) return 'Hmm, request format invalid (422). I fixed the body—try again.';
    if (code != null) {
      final details =
          (body is Map && body['detail'] != null) ? body['detail'].toString() : message;
      return 'Error $code: ${details ?? 'server error'}';
    }
    return 'Network error: ${message ?? 'check connection'}';
  }

  String _extractReply(dynamic data) {
    // 兼容 {data:{reply}}, {reply}, {message} 三种
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

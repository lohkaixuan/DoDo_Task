import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/petChatController.dart';
import '../widgets/pet_header.dart';

class PetChatScreen extends StatelessWidget {
  const PetChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PetChatController(), permanent: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Pet AI')),
      body: Column(
        children: [
          // Cute header (uses PetHeader)
          const PetHeader(statusOverride: 'Chat with your buddy'),
          Expanded(
            child: Obx(() {
              return ListView.builder(
                controller: c.scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: c.messages.length,
                itemBuilder: (_, i) => _Bubble(m: c.messages[i]),
              );
            }),
          ),
          Obx(() => _Typing(isTyping: c.isSending.value)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c.input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) async => c.send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:() async => await c.send(),
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(14)),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final isMe = m.fromUser;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isMe ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    final fg = isMe ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(isMe ? 48 : 8, 4, isMe ? 8 : 48, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Text(m.text, style: TextStyle(color: fg)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(isMe ? 0 : 12, 0, isMe ? 12 : 0, 4),
          child: Text(
            _fmt(m.ts),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = dt.toLocal();
    return '${two(d.hour)}:${two(d.minute)}';
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.isTyping});
  final bool isTyping;
  @override
  Widget build(BuildContext context) {
    if (!isTyping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: const [
          SizedBox(width: 6),
          _Dot(),
          SizedBox(width: 4),
          _Dot(delayMs: 150),
          SizedBox(width: 4),
          _Dot(delayMs: 300),
          SizedBox(width: 10),
          Text('Pet is thinking…', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({this.delayMs = 0});
  final int delayMs;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: const CircleAvatar(radius: 3, backgroundColor: Colors.grey),
    );
  }
}

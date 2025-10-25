import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';

class CaroChatPanel extends StatefulWidget {
  final CaroController controller;

  const CaroChatPanel({super.key, required this.controller});

  @override
  State<CaroChatPanel> createState() => _CaroChatPanelState();
}

class _CaroChatPanelState extends State<CaroChatPanel> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen để rebuild khi có message mới
    widget.controller.addListener(_onChatUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChatUpdate);
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatUpdate() {
    // Rebuild widget khi có message mới
    if (mounted) {
      setState(() {});
      // Auto scroll to bottom
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    widget.controller.sendChat(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chats = widget.controller.chatMessages;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          // 🧠 Header
          Container(
            color: Colors.deepPurple.shade100,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 6),
                Text(
                  "Chat (${chats.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // 🧩 Danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: chats.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final msg = chats[index];
                final fromUserId = msg["from"];
                final fromMe = fromUserId == widget.controller.myUserId;
                final time =
                    msg["time"]?.toString().split("T").last.split(".").first ??
                    "";

                return Align(
                  alignment: fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: fromMe
                          ? Colors.blueAccent.withOpacity(0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: fromMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!fromMe)
                          Text(
                            "Đối thủ",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        Text(
                          msg["message"] ?? "",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 📝 Ô nhập chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.deepPurple,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

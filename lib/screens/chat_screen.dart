import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../providers/app_provider.dart';

class ChatScreen extends StatefulWidget {
  final Peer peer;
  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _ghost = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppProvider>().loadMessages(widget.peer.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<AppProvider>().sendMessage(
          peerId: widget.peer.id,
          text: text,
          ghost: _ghost,
        );
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final peer = provider.peers[widget.peer.id] ?? widget.peer;
    final messages = provider.messagesFor(widget.peer.id);

    return Scaffold(
      backgroundColor: const Color(0xFF080F08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FF41)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              peer.name,
              style: const TextStyle(
                color: Color(0xFF00FF41),
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              peer.isConnected ? '● CONNECTED' : '○ DISCONNECTED',
              style: TextStyle(
                color: peer.isConnected
                    ? const Color(0xFF00FF41)
                    : const Color(0xFF555555),
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _ghost = !_ghost),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _ghost
                      ? Colors.purpleAccent
                      : const Color(0xFF00FF41).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(4),
                color: _ghost
                    ? Colors.purpleAccent.withOpacity(0.15)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👻', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    'GHOST',
                    style: TextStyle(
                      color: _ghost ? Colors.purpleAccent : Colors.grey,
                      fontFamily: 'monospace',
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_ghost)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.purple.withOpacity(0.15),
              child: const Text(
                '👻 Ghost mode ON · messages vanish when peer is lost',
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSay hello!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF336633),
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) =>
                        _bubble(messages[i], messages[i].isMine),
                  ),
          ),
          _inputBar(peer.isConnected),
        ],
      ),
    );
  }

  Widget _bubble(Message m, bool isMe) {
    final bg = m.isGhost
        ? (isMe
            ? Colors.purple.withOpacity(0.3)
            : Colors.purple.withOpacity(0.2))
        : (isMe
            ? const Color(0xFF1A4A1A)
            : const Color(0xFF0D1F0D));

    final border = m.isGhost
        ? Colors.purpleAccent.withOpacity(0.5)
        : const Color(0xFF00FF41).withOpacity(0.2);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isMe ? 8 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 8),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m.isGhost)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '👻 ghost',
                  style: TextStyle(
                    color: Colors.purpleAccent.withOpacity(0.7),
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Text(
              m.text,
              style: const TextStyle(
                color: Color(0xFFCCFFCC),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(m.timestamp),
                  style: TextStyle(
                    color: const Color(0xFF00FF41).withOpacity(0.5),
                    fontFamily: 'monospace',
                    fontSize: 9,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _statusIcon(m.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 10, color: Color(0xFF336633));
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 10, color: Color(0xFF00FF41));
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 10, color: Color(0xFF00FF41));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 10, color: Colors.red);
    }
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _inputBar(bool enabled) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border(
          top: BorderSide(color: const Color(0xFF00FF41).withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: enabled,
              style: const TextStyle(
                color: Color(0xFFCCFFCC),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: enabled
                    ? (_ghost ? '👻 Ghost message…' : 'Message…')
                    : 'Disconnected',
                hintStyle: TextStyle(
                  color: _ghost
                      ? Colors.purpleAccent.withOpacity(0.4)
                      : const Color(0xFF336633),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                border: _border(),
                enabledBorder: _border(),
                focusedBorder: _border(focused: true),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? _send : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ghost
                    ? Colors.purple.withOpacity(0.3)
                    : const Color(0xFF1A4A1A),
                border: Border.all(
                  color: _ghost
                      ? Colors.purpleAccent
                      : const Color(0xFF00FF41),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.send,
                color: _ghost
                    ? Colors.purpleAccent
                    : const Color(0xFF00FF41),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border({bool focused = false}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: _ghost
              ? Colors.purpleAccent
                  .withOpacity(focused ? 1 : 0.4)
              : const Color(0xFF00FF41)
                  .withOpacity(focused ? 1 : 0.3),
        ),
      );
}

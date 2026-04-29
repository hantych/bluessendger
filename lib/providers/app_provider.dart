import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/peer.dart';
import '../services/mesh_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();
  late MeshService _mesh;

  String _myName = 'Ghost';
  String get myName => _myName;

  bool _initialized = false;
  bool get initialized => _initialized;

  /// peerId -> Peer
  final Map<String, Peer> _peers = {};
  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  List<Peer> get peerList => _peers.values.toList();

  /// peerId -> messages
  final Map<String, List<Message>> _messages = {};

  /// peerId where chat is currently open (suppress notifications for that one)
  String? _activeChatId;

  /// Track ghost message IDs per peer so we can wipe them when peer is lost.
  final Map<String, List<String>> _ghostIds = {};

  /// Recent activity log, useful for debugging.
  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  Future<void> init() async {
    if (_initialized) return;

    await _notifications.init();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('my_name');
    if (saved != null && saved.isNotEmpty) {
      _myName = saved;
    } else {
      _myName = await _detectDeviceName();
      await prefs.setString('my_name', _myName);
    }

    _mesh = MeshService(
      onPeerUpdate: _onPeerUpdate,
      onPeerLost: _onPeerLost,
      onMessage: _onMessage,
      onLog: _addLog,
    );

    await _mesh.start(_myName);

    _initialized = true;
    notifyListeners();
  }

  Future<String> _detectDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      // Prefer the user-set device name if available, fall back to model.
      final name = android.model;
      return name.isNotEmpty ? name : 'Android Device';
    } catch (_) {
      return 'Ghost Device';
    }
  }

  void _addLog(String line) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[mesh] $line');
    }
    _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  $line');
    if (_log.length > 100) _log.removeLast();
    notifyListeners();
  }

  // ─── Peer events ─────────────────────────────────────────────────────

  void _onPeerUpdate(Peer peer) {
    final existing = _peers[peer.id];
    // Preserve name if the new event has empty/unknown name.
    final nameToUse =
        peer.name.isNotEmpty ? peer.name : (existing?.name ?? 'Unknown');
    _peers[peer.id] = peer.copyWith(name: nameToUse);
    notifyListeners();
  }

  void _onPeerLost(String peerId) {
    final p = _peers[peerId];
    if (p != null) {
      _peers[peerId] = p.copyWith(state: PeerState.disconnected);
    }
    // Wipe ghost messages tied to this peer.
    _wipeGhostsFor(peerId);
    notifyListeners();
  }

  Future<void> _wipeGhostsFor(String peerId) async {
    final ids = _ghostIds.remove(peerId);
    if (ids == null || ids.isEmpty) return;

    for (final id in ids) {
      await _storage.deleteMessage(id);
    }
    final list = _messages[peerId];
    if (list != null) {
      for (final msg in list) {
        if (ids.contains(msg.id)) msg.isDeleted = true;
      }
    }
  }

  // ─── Messages ────────────────────────────────────────────────────────

  void _onMessage(String peerId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';

    if (type == 'message') {
      final id = data['id'] as String;
      final isGhost = data['ghost'] as bool? ?? false;

      final msg = Message(
        id: id,
        chatId: peerId,
        senderId: peerId,
        text: data['text'] as String? ?? '',
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(data['ts'] as int? ?? 0),
        status: MessageStatus.delivered,
        isGhost: isGhost,
      );

      _storage.insertMessage(msg);
      _messages.putIfAbsent(peerId, () => []);
      if (!_messages[peerId]!.any((m) => m.id == msg.id)) {
        _messages[peerId]!.add(msg);
      }

      if (isGhost) {
        _ghostIds.putIfAbsent(peerId, () => []).add(id);
      }

      // Send delivery ack
      _mesh.sendMessage(peerId, {'type': 'ack', 'id': id});

      // Show notification only if chat is not open
      final senderName = _peers[peerId]?.name ?? 'Unknown';
      if (_activeChatId != peerId) {
        _notifications.showMessage(
          senderName: senderName,
          message: msg.text,
          chatId: peerId,
        );
      }

      notifyListeners();
    } else if (type == 'ack') {
      final id = data['id'] as String?;
      if (id == null) return;
      _storage.updateStatus(id, MessageStatus.delivered);
      final list = _messages[peerId];
      if (list != null) {
        for (final m in list) {
          if (m.id == id) m.status = MessageStatus.delivered;
        }
      }
      notifyListeners();
    } else if (type == 'ghost_wipe') {
      final id = data['id'] as String?;
      if (id != null) {
        _storage.deleteMessage(id);
        for (final list in _messages.values) {
          for (final m in list) {
            if (m.id == id) m.isDeleted = true;
          }
        }
        notifyListeners();
      }
    }
  }

  Future<void> sendMessage({
    required String peerId,
    required String text,
    bool ghost = false,
  }) async {
    final msg = Message(
      id: const Uuid().v4(),
      chatId: peerId,
      senderId: Message.myIdMarker,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isGhost: ghost,
    );

    await _storage.insertMessage(msg);
    _messages.putIfAbsent(peerId, () => []).add(msg);
    if (ghost) _ghostIds.putIfAbsent(peerId, () => []).add(msg.id);
    notifyListeners();

    final ok = await _mesh.sendMessage(peerId, msg.toWire());
    msg.status = ok ? MessageStatus.sent : MessageStatus.failed;
    await _storage.updateStatus(msg.id, msg.status);
    notifyListeners();
  }

  Future<void> loadMessages(String peerId) async {
    final saved = await _storage.getMessages(peerId);
    _messages[peerId] = saved;
    notifyListeners();
  }

  List<Message> messagesFor(String peerId) =>
      (_messages[peerId] ?? []).where((m) => !m.isDeleted).toList();

  void setActiveChat(String? peerId) {
    _activeChatId = peerId;
  }

  Future<void> setMyName(String name) async {
    if (name.trim().isEmpty) return;
    _myName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_name', _myName);
    // Restart mesh so the new name is advertised.
    await _mesh.stop();
    _peers.clear();
    await _mesh.start(_myName);
    notifyListeners();
  }

  @override
  void dispose() {
    _mesh.stop();
    super.dispose();
  }
}

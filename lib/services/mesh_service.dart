import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../models/peer.dart';

/// Strategy:
///  - P2P_CLUSTER: many-to-many mesh (any device can talk to any other in range).
///    Uses BLE for discovery + Bluetooth Classic / Wi-Fi Hotspot for data.
///    Range: ~30-100m typical, no internet required.
const Strategy _kStrategy = Strategy.P2P_CLUSTER;

/// Unique identifier for our app — both devices must use the same value
/// or they will not see each other.
const String _kServiceId = 'com.ghostmesh.app';

typedef PeerUpdateCallback = void Function(Peer peer);
typedef PeerLostCallback = void Function(String peerId);
typedef MessageCallback =
    void Function(String peerId, Map<String, dynamic> data);
typedef LogCallback = void Function(String line);

/// Wrapper around Google Nearby Connections that gives us:
///   - automatic discovery + advertising in parallel
///   - auto-accept of any incoming connection
///   - JSON message channel
class MeshService {
  final PeerUpdateCallback onPeerUpdate;
  final PeerLostCallback onPeerLost;
  final MessageCallback onMessage;
  final LogCallback onLog;

  String _myName = 'unknown';
  bool _started = false;

  /// endpointId -> peer name (stored so we can reconstruct Peer on state changes)
  final Map<String, String> _peerNames = {};

  MeshService({
    required this.onPeerUpdate,
    required this.onPeerLost,
    required this.onMessage,
    required this.onLog,
  });

  String get myName => _myName;

  Future<void> start(String myName) async {
    if (_started) return;
    _myName = myName;

    try {
      await Nearby().startAdvertising(
        myName,
        _kStrategy,
        serviceId: _kServiceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      onLog('Advertising as "$myName"');
    } catch (e) {
      onLog('Advertising failed: $e');
    }

    try {
      await Nearby().startDiscovery(
        myName,
        _kStrategy,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLostInternal,
      );
      onLog('Discovery started');
    } catch (e) {
      onLog('Discovery failed: $e');
    }

    _started = true;
  }

  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _peerNames.clear();
    _started = false;
  }

  // ─── Discovery callbacks ───────────────────────────────────────────────

  void _onEndpointFound(String id, String name, String serviceId) {
    onLog('Found: $name ($id)');
    _peerNames[id] = name;
    onPeerUpdate(
      Peer(
        id: id,
        name: name,
        state: PeerState.discovered,
        lastSeen: DateTime.now(),
      ),
    );

    // Auto-request connection so chat is ready instantly.
    Nearby()
        .requestConnection(
          _myName,
          id,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        )
        .then((_) {
      onPeerUpdate(
        Peer(
          id: id,
          name: name,
          state: PeerState.connecting,
          lastSeen: DateTime.now(),
        ),
      );
    }).catchError((e) {
      onLog('requestConnection failed for $name: $e');
    });
  }

  void _onEndpointLostInternal(String? id) {
    if (id == null) return;
    onLog('Lost: $id');
    _peerNames.remove(id);
    onPeerLost(id);
  }

  // ─── Connection lifecycle ──────────────────────────────────────────────

  /// Both sides receive this when a connection is being negotiated.
  /// We auto-accept (no PIN UX, since the user wanted no setup friction).
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    onLog('Connection initiated with ${info.endpointName}');
    _peerNames[id] = info.endpointName;

    onPeerUpdate(
      Peer(
        id: id,
        name: info.endpointName,
        state: PeerState.connecting,
        lastSeen: DateTime.now(),
      ),
    );

    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (_, __) {},
    );
  }

  void _onConnectionResult(String id, Status status) {
    final name = _peerNames[id] ?? 'Unknown';
    onLog('Connection result for $name: $status');

    if (status == Status.CONNECTED) {
      onPeerUpdate(
        Peer(
          id: id,
          name: name,
          state: PeerState.connected,
          lastSeen: DateTime.now(),
        ),
      );
    } else {
      onPeerUpdate(
        Peer(
          id: id,
          name: name,
          state: PeerState.disconnected,
          lastSeen: DateTime.now(),
        ),
      );
    }
  }

  void _onDisconnected(String id) {
    final name = _peerNames[id] ?? 'Unknown';
    onLog('Disconnected: $name');
    onPeerUpdate(
      Peer(
        id: id,
        name: name,
        state: PeerState.disconnected,
        lastSeen: DateTime.now(),
      ),
    );
  }

  // ─── Payload handling ──────────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null) return;

    try {
      final str = utf8.decode(bytes);
      final data = jsonDecode(str) as Map<String, dynamic>;
      onMessage(endpointId, data);
    } catch (e) {
      onLog('Failed to decode payload: $e');
    }
  }

  /// Send a JSON-encoded message to the given peer.
  /// Returns true if Nearby accepted the payload for delivery.
  Future<bool> sendMessage(
    String peerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      await Nearby().sendBytesPayload(peerId, bytes);
      return true;
    } catch (e) {
      onLog('Send failed: $e');
      return false;
    }
  }
}

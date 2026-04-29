/// Represents a discovered nearby peer device.
class Peer {
  /// Stable endpoint ID assigned by Nearby Connections.
  final String id;

  /// Device name advertised by the peer (their device model/nickname).
  final String name;

  /// Whether we currently have an active connection to this peer.
  final PeerState state;

  /// Timestamp of last activity (discovery or message).
  final DateTime lastSeen;

  const Peer({
    required this.id,
    required this.name,
    required this.state,
    required this.lastSeen,
  });

  bool get isConnected => state == PeerState.connected;
  bool get isDiscovered => state == PeerState.discovered;
  bool get isConnecting => state == PeerState.connecting;

  Peer copyWith({
    String? id,
    String? name,
    PeerState? state,
    DateTime? lastSeen,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum PeerState {
  /// Device was found via Nearby Connections discovery but no socket yet.
  discovered,

  /// Currently negotiating the connection (auth/handshake).
  connecting,

  /// Active duplex connection — can send messages.
  connected,

  /// Connection lost or disconnected.
  disconnected,
}
